#!/bin/bash

# FASE 6: CLEANUP NUCLEARE - RIMUOVE TUTTO SENZA PIETÀ
# Quando il cleanup normale non basta, usiamo la forza bruta

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="crm-system"
KUBECTL_CMD="kubectl"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${RED}=== 💥 CLEANUP NUCLEARE KUBERNETES ===${NC}"
echo "Target: $NAMESPACE"
echo "Kubectl: $KUBECTL_CMD"
echo ""

confirm_nuclear() {
    echo -e "${YELLOW}⚠️  CLEANUP NUCLEARE - RIMUOVE TUTTO CON FORZA BRUTA!${NC}"
    echo ""
    echo -e "${RED}Questo script useranno opzioni --force --grace-period=0 su TUTTO${NC}"
    echo ""
    read -p "Procedere con cleanup nucleare? (scrivi 'NUCLEARE' per confermare): " confirm
    
    if [ "$confirm" != "NUCLEARE" ]; then
        echo "Cleanup annullato"
        exit 0
    fi
}

# Step 1: Nuclear endpoints cleanup
nuclear_endpoints_cleanup() {
    echo -e "${BLUE}💥 NUCLEAR: Cleanup endpoints in TUTTI i namespace${NC}"
    
    # Find ALL postgres-service endpoints everywhere
    echo "Trovando tutti gli endpoints postgres-service..."
    POSTGRES_ENDPOINTS=$($KUBECTL_CMD get endpoints --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' | grep postgres-service || echo "")
    
    if [ -n "$POSTGRES_ENDPOINTS" ]; then
        echo "Trovati endpoints postgres-service:"
        echo "$POSTGRES_ENDPOINTS"
        
        echo "$POSTGRES_ENDPOINTS" | while read endpoint; do
            if [ -n "$endpoint" ]; then
                NAMESPACE_EP=$(echo "$endpoint" | cut -d'/' -f1)
                NAME_EP=$(echo "$endpoint" | cut -d'/' -f2)
                echo "Force deleting endpoint: $NAME_EP in namespace $NAMESPACE_EP"
                $KUBECTL_CMD delete endpoints "$NAME_EP" -n "$NAMESPACE_EP" --force --grace-period=0 2>/dev/null || true
            fi
        done
    fi
    
    # Delete ALL CRM-related endpoints
    echo "Cancellando TUTTI gli endpoints CRM..."
    $KUBECTL_CMD get endpoints --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace} {.metadata.name}{"\n"}{end}' | grep -E "(crm|postgres|backend|frontend)" | while read ns name; do
        echo "Force deleting endpoint: $name in namespace $ns"
        $KUBECTL_CMD delete endpoints "$name" -n "$ns" --force --grace-period=0 2>/dev/null || true
    done
}

# Step 2: Nuclear namespace cleanup
nuclear_namespace_cleanup() {
    echo -e "${BLUE}💥 NUCLEAR: Cleanup namespace $NAMESPACE${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo "Namespace $NAMESPACE non esiste"
        return 0
    fi
    
    # Patch finalizers on ALL resources in namespace
    echo "Rimozione finalizers da tutte le risorse..."
    
    # Get all resource types in namespace
    RESOURCE_TYPES=$($KUBECTL_CMD api-resources --verbs=list --namespaced -o name 2>/dev/null || echo "")
    
    if [ -n "$RESOURCE_TYPES" ]; then
        echo "$RESOURCE_TYPES" | while read resource; do
            echo "Patching finalizers for resource type: $resource"
            $KUBECTL_CMD get "$resource" -n "$NAMESPACE" -o name 2>/dev/null | while read res; do
                $KUBECTL_CMD patch "$res" -n "$NAMESPACE" -p '{"metadata":{"finalizers":null}}' --type merge 2>/dev/null || true
            done
        done
    fi
    
    # Force delete namespace
    echo "Force deleting namespace..."
    $KUBECTL_CMD delete namespace "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    
    # If still exists, patch namespace finalizers
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo "Namespace ancora presente, patching finalizers..."
        $KUBECTL_CMD patch namespace $NAMESPACE -p '{"metadata":{"finalizers":null}}' --type merge 2>/dev/null || true
    fi
    
    # Wait for deletion
    echo "Aspettando cancellazione namespace..."
    TIMEOUT=60
    ELAPSED=0
    while $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
        echo "Aspettando... ($ELAPSED/$TIMEOUT)"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
}

# Step 3: Nuclear PV cleanup
nuclear_pv_cleanup() {
    echo -e "${BLUE}💥 NUCLEAR: Cleanup Persistent Volumes${NC}"
    
    # Find ALL CRM-related PVs
    echo "Trovando tutti i PV CRM..."
    PV_LIST=$($KUBECTL_CMD get pv -o jsonpath='{range .items[*]}{.metadata.name} {.spec.claimRef.namespace} {.spec.claimRef.name}{"\n"}{end}' 2>/dev/null | grep -E "(crm|postgres)" || echo "")
    
    if [ -n "$PV_LIST" ]; then
        echo "Trovati PV CRM:"
        echo "$PV_LIST"
        
        echo "$PV_LIST" | while read pv_name ns claim; do
            if [ -n "$pv_name" ] && [ "$pv_name" != "<none>" ]; then
                echo "Patching PV finalizers: $pv_name"
                $KUBECTL_CMD patch pv "$pv_name" -p '{"metadata":{"finalizers":null}}' --type merge 2>/dev/null || true
                
                echo "Force deleting PV: $pv_name"
                $KUBECTL_CMD delete pv "$pv_name" --force --grace-period=0 2>/dev/null || true
            fi
        done
    fi
    
    # Double check for any remaining CRM PVs
    REMAINING_PVS=$($KUBECTL_CMD get pv 2>/dev/null | grep -E "(crm|postgres)" | awk '{print $1}' || echo "")
    if [ -n "$REMAINING_PVS" ]; then
        echo "PV CRM rimanenti, force delete..."
        echo "$REMAINING_PVS" | while read pv; do
            $KUBECTL_CMD patch pv "$pv" -p '{"metadata":{"finalizers":null}}' --type merge 2>/dev/null || true
            $KUBECTL_CMD delete pv "$pv" --force --grace-period=0 2>/dev/null || true
        done
    fi
}

# Step 4: Nuclear etcd cleanup (se disponibile)
nuclear_etcd_cleanup() {
    echo -e "${BLUE}💥 NUCLEAR: Cleanup etcd CRM keys${NC}"
    
    # Try to clean etcd keys if accessible (k3s specific)
    if command -v k3s &>/dev/null; then
        echo "Tentativo cleanup chiavi etcd k3s..."
        
        # This is dangerous but necessary for stuck resources
        sudo k3s etcd-snapshot save nuclear-pre-cleanup 2>/dev/null || true
        
        # Force restart k3s to clear any stuck state
        echo "Restart k3s per clear stuck state..."
        sudo systemctl restart k3s 2>/dev/null || true
        sleep 10
        
        # Wait for k3s to be ready
        echo "Aspettando k3s ready..."
        TIMEOUT=60
        ELAPSED=0
        while ! $KUBECTL_CMD cluster-info &>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
            echo "k3s non ancora ready... ($ELAPSED/$TIMEOUT)"
            sleep 5
            ELAPSED=$((ELAPSED + 5))
        done
        
        if $KUBECTL_CMD cluster-info &>/dev/null; then
            echo -e "${GREEN}✅ k3s riavviato e pronto${NC}"
        else
            echo -e "${RED}❌ k3s non risponde dopo restart${NC}"
        fi
    fi
}

# Main nuclear cleanup
main() {
    local mode=${1:-interactive}
    
    case $mode in
        --auto)
            echo -e "${RED}🚨 CLEANUP NUCLEARE AUTOMATICO${NC}"
            nuclear_endpoints_cleanup
            nuclear_namespace_cleanup
            nuclear_pv_cleanup
            nuclear_etcd_cleanup
            ;;
        --endpoints-only)
            echo -e "${BLUE}💥 CLEANUP NUCLEARE: Solo Endpoints${NC}"
            nuclear_endpoints_cleanup
            ;;
        --help)
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  (no option)        Cleanup nucleare interattivo completo"
            echo "  --auto             Cleanup nucleare automatico"
            echo "  --endpoints-only   Cleanup solo endpoints appesi"
            echo "  --help             Mostra questo aiuto"
            echo ""
            echo "ATTENZIONE: Questo script usa --force --grace-period=0"
            echo "Usare solo quando il cleanup normale fallisce!"
            exit 0
            ;;
        *)
            # Interactive mode
            confirm_nuclear
            nuclear_endpoints_cleanup
            nuclear_namespace_cleanup
            nuclear_pv_cleanup
            nuclear_etcd_cleanup
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ CLEANUP NUCLEARE COMPLETATO${NC}"
    echo ""
    echo "Verifica stato cluster:"
    echo "kubectl get namespaces"
    echo "kubectl get endpoints --all-namespaces | grep postgres"
    echo "kubectl get pv"
    echo ""
    echo "Poi procedi con: ./deploy-k8s.sh start"
}

main "$@"
