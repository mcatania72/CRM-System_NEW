#!/bin/bash

# FASE 6: Cleanup OMNICOMPRENSIVO del namespace Kubernetes
# Rimuove TUTTO il deployment CRM dal cluster K8s, inclusi residui nascosti

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="crm-system"
KUBECTL_CMD="kubectl"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 🧹 FASE 6: CLEANUP OMNICOMPRENSIVO ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Kubectl: $KUBECTL_CMD"
echo ""

# Function to confirm action
confirm_cleanup() {
    echo -e "${YELLOW}⚠️  WARNING: CLEANUP OMNICOMPRENSIVO - RIMUOVE TUTTO!${NC}"
    echo ""
    echo -e "${RED}Questo cancellerà COMPLETAMENTE:${NC}"
    echo "  🗑️  Namespace $NAMESPACE e tutto il contenuto"
    echo "  🗑️  Tutti i pod, deployment, service, ingress"
    echo "  🗑️  Persistent Volume Claims (PERDITA DATI!)"
    echo "  🗑️  Secrets, ConfigMaps, ServiceAccounts"
    echo "  🗑️  Endpoints, ReplicaSets, Jobs, CronJobs"
    echo "  🗑️  HorizontalPodAutoscaler, PodDisruptionBudgets"
    echo "  🗑️  NetworkPolicies, ResourceQuotas"
    echo "  🗑️  Orphaned Persistent Volumes CRM"
    echo "  🗑️  Immagini Docker CRM (opzionale)"
    echo ""
    echo -e "${CYAN}Verranno preservati:${NC}"
    echo "  ✅ Altri namespace"
    echo "  ✅ Storage classes"
    echo "  ✅ Cluster nodes e sistema"
    echo ""
    
    read -p "Sei sicuro di voler procedere? (scrivi 'RIMUOVI TUTTO' per confermare): " confirmation
    
    if [ "$confirmation" != "RIMUOVI TUTTO" ]; then
        echo -e "${GREEN}✅ Cleanup annullato${NC}"
        exit 0
    fi
}

# Function to backup data before cleanup
backup_data() {
    echo -e "${BLUE}💾 Creazione backup prima del cleanup...${NC}"
    
    # Create backup directory
    BACKUP_DIR="$HOME/crm-k8s-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo "Directory backup: $BACKUP_DIR"
    
    # Check if namespace exists
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE non esiste, skip backup${NC}"
        return 0
    fi
    
    # Export all resources
    echo "Esportazione risorse Kubernetes..."
    $KUBECTL_CMD get all -n $NAMESPACE -o yaml > "$BACKUP_DIR/all-resources.yaml" 2>/dev/null || true
    $KUBECTL_CMD get pvc -n $NAMESPACE -o yaml > "$BACKUP_DIR/pvc-resources.yaml" 2>/dev/null || true
    $KUBECTL_CMD get secrets -n $NAMESPACE -o yaml > "$BACKUP_DIR/secrets.yaml" 2>/dev/null || true
    $KUBECTL_CMD get configmaps -n $NAMESPACE -o yaml > "$BACKUP_DIR/configmaps.yaml" 2>/dev/null || true
    $KUBECTL_CMD get endpoints -n $NAMESPACE -o yaml > "$BACKUP_DIR/endpoints.yaml" 2>/dev/null || true
    $KUBECTL_CMD get networkpolicies -n $NAMESPACE -o yaml > "$BACKUP_DIR/networkpolicies.yaml" 2>/dev/null || true
    $KUBECTL_CMD get hpa -n $NAMESPACE -o yaml > "$BACKUP_DIR/hpa.yaml" 2>/dev/null || true
    $KUBECTL_CMD get pdb -n $NAMESPACE -o yaml > "$BACKUP_DIR/pdb.yaml" 2>/dev/null || true
    
    # Database backup if possible
    echo "Tentativo backup database..."
    POSTGRES_POD=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ] && [ "$POSTGRES_POD" != "<no value>" ]; then
        echo "Creazione dump database PostgreSQL..."
        $KUBECTL_CMD exec $POSTGRES_POD -n $NAMESPACE -- pg_dump -U postgres -d crm > "$BACKUP_DIR/database-dump.sql" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Backup database fallito (pod non pronto)${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  Nessun pod PostgreSQL trovato per backup${NC}"
    fi
    
    # Create summary file
    cat > "$BACKUP_DIR/backup-info.txt" << EOF
CRM Kubernetes Backup
Creato: $(date)
Namespace: $NAMESPACE
Hostname: $(hostname)
Kubectl: $KUBECTL_CMD

File inclusi:
- all-resources.yaml: Tutti i workload
- pvc-resources.yaml: Persistent Volume Claims
- secrets.yaml: Secrets e credenziali
- configmaps.yaml: ConfigMaps
- endpoints.yaml: Endpoints services
- networkpolicies.yaml: Network policies
- hpa.yaml: Horizontal Pod Autoscalers
- pdb.yaml: Pod Disruption Budgets
- database-dump.sql: Dump database PostgreSQL (se disponibile)

Per ripristinare:
1. kubectl create namespace $NAMESPACE
2. kubectl apply -f secrets.yaml
3. kubectl apply -f configmaps.yaml  
4. kubectl apply -f pvc-resources.yaml
5. kubectl apply -f all-resources.yaml
EOF
    
    echo -e "${GREEN}✅ Backup creato in: $BACKUP_DIR${NC}"
}

# Function to force terminate all workloads
force_terminate_workloads() {
    echo -e "${BLUE}🛑 Force terminate di tutti i workload...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE non esiste${NC}"
        return 0
    fi
    
    # Scale all deployments to 0
    echo "Scaling down deployments..."
    $KUBECTL_CMD scale deployment --all --replicas=0 -n $NAMESPACE 2>/dev/null || true
    
    # Delete all StatefulSets
    echo "Deleting StatefulSets..."
    $KUBECTL_CMD delete statefulset --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Delete all DaemonSets
    echo "Deleting DaemonSets..."
    $KUBECTL_CMD delete daemonset --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Delete all Jobs and CronJobs
    echo "Deleting Jobs and CronJobs..."
    $KUBECTL_CMD delete job --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    $KUBECTL_CMD delete cronjob --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Force delete all pods
    echo "Force deleting all pods..."
    $KUBECTL_CMD delete pods --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Wait a bit for termination
    echo "Aspettando terminazione pod..."
    sleep 5
    
    echo -e "${GREEN}✅ Workload terminati${NC}"
}

# Function to delete ALL resources (omnicomprensivo)
delete_all_resources() {
    echo -e "${BLUE}🗑️  Cancellazione OMNICOMPRENSIVA di tutte le risorse...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE non esiste${NC}"
        return 0
    fi
    
    # Delete in reverse dependency order
    
    echo "Deleting Ingress resources..."
    $KUBECTL_CMD delete ingress --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting HorizontalPodAutoscalers..."
    $KUBECTL_CMD delete hpa --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting PodDisruptionBudgets..."
    $KUBECTL_CMD delete pdb --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting NetworkPolicies..."
    $KUBECTL_CMD delete networkpolicy --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Force deleting Services..."
    $KUBECTL_CMD delete svc --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Force deleting Endpoints (inclusi quelli appesi)..."
    $KUBECTL_CMD delete endpoints --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Force deleting ReplicaSets..."
    $KUBECTL_CMD delete rs --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Force deleting Deployments..."
    $KUBECTL_CMD delete deployment --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting ConfigMaps..."
    $KUBECTL_CMD delete configmap --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting Secrets..."
    $KUBECTL_CMD delete secret --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting ServiceAccounts..."
    $KUBECTL_CMD delete serviceaccount --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting ResourceQuotas..."
    $KUBECTL_CMD delete resourcequota --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo "Deleting LimitRanges..."
    $KUBECTL_CMD delete limitrange --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    echo -e "${GREEN}✅ Tutte le risorse cancellate${NC}"
}

# Function to delete persistent storage (PERDITA DATI!)
delete_storage_omnicomprensivo() {
    echo -e "${BLUE}💾 Cancellazione OMNICOMPRENSIVA storage...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE non esiste${NC}"
        return 0
    fi
    
    # List PVCs before deletion
    echo "PVC attuali:"
    $KUBECTL_CMD get pvc -n $NAMESPACE 2>/dev/null || echo "Nessun PVC trovato"
    
    # Delete PVCs (PERDITA DATI!)
    echo -e "${RED}⚠️  Cancellazione PVC (PERDITA DATI!)...${NC}"
    $KUBECTL_CMD delete pvc --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Wait for PV cleanup
    echo "Aspettando cleanup Persistent Volumes..."
    sleep 15
    
    # Find and delete orphaned PVs for CRM
    echo "Ricerca Persistent Volumes orfani CRM..."
    ORPHANED_PVS=$($KUBECTL_CMD get pv -o jsonpath='{range .items[*]}{.metadata.name} {.spec.claimRef.namespace} {.spec.claimRef.name}{"\n"}{end}' 2>/dev/null | grep -E "(crm-system|crm-|postgres-)" | awk '{print $1}' || echo "")
    
    if [ -n "$ORPHANED_PVS" ]; then
        echo "Trovati PV orfani CRM, cleanup..."
        echo "$ORPHANED_PVS" | while read pv; do
            if [ -n "$pv" ]; then
                echo "Cancellando PV orfano: $pv"
                $KUBECTL_CMD delete pv "$pv" --force --grace-period=0 2>/dev/null || true
            fi
        done
    else
        echo "Nessun PV orfano CRM trovato"
    fi
    
    # Check for any remaining CRM-related PVs
    echo "Verifica finale PV CRM..."
    REMAINING_PVS=$($KUBECTL_CMD get pv 2>/dev/null | grep -E "(crm-|postgres)" || echo "")
    if [ -n "$REMAINING_PVS" ]; then
        echo -e "${YELLOW}⚠️  PV CRM rimanenti:${NC}"
        echo "$REMAINING_PVS"
    else
        echo -e "${GREEN}✅ Nessun PV CRM rimanente${NC}"
    fi
    
    echo -e "${GREEN}✅ Storage cleanup completato${NC}"
}

# Function to delete namespace (finale)
delete_namespace_final() {
    echo -e "${BLUE}📁 Cancellazione finale namespace...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE già rimosso${NC}"
        return 0
    fi
    
    # Final namespace deletion
    echo "Cancellando namespace $NAMESPACE..."
    $KUBECTL_CMD delete namespace $NAMESPACE --force --grace-period=0 2>/dev/null || true
    
    # Wait for namespace deletion with timeout
    echo "Aspettando cancellazione namespace (max 5 minuti)..."
    TIMEOUT=300
    ELAPSED=0
    
    while $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
        echo "Namespace ancora presente, aspettando... ($ELAPSED/$TIMEOUT sec)"
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non cancellato entro timeout${NC}"
        echo "Potrebbe essere bloccato da finalizers. Forza rimozione finalizers..."
        
        # Try to remove finalizers
        $KUBECTL_CMD patch namespace $NAMESPACE -p '{"metadata":{"finalizers":null}}' --type merge 2>/dev/null || true
        sleep 5
        
        if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
            echo -e "${RED}❌ Namespace ancora presente. Potrebbe richiedere intervento manuale.${NC}"
        else
            echo -e "${GREEN}✅ Namespace rimosso dopo patch finalizers${NC}"
        fi
    else
        echo -e "${GREEN}✅ Namespace $NAMESPACE cancellato${NC}"
    fi
}

# Function to clean up Docker images (omnicomprensivo)
cleanup_docker_images_omnicomprensivo() {
    echo -e "${BLUE}🐳 Cleanup OMNICOMPRENSIVO immagini Docker...${NC}"
    
    # List all CRM-related images
    echo "Immagini Docker CRM attuali:"
    docker images | grep -E "(crm-|postgres)" 2>/dev/null || echo "Nessuna immagine CRM trovata"
    
    # List k3s containerd images
    echo ""
    echo "Immagini k3s containerd CRM:"
    sudo k3s ctr images list | grep -E "(crm-|postgres)" 2>/dev/null || echo "Nessuna immagine CRM in k3s"
    
    echo ""
    read -p "Rimuovere TUTTE le immagini CRM (Docker + k3s)? (y/n): " remove_images
    
    if [ "$remove_images" = "y" ] || [ "$remove_images" = "Y" ]; then
        echo "Rimozione immagini Docker CRM..."
        
        # Remove Docker images
        DOCKER_IMAGES=$(docker images | grep -E "(crm-|postgres)" | awk '{print $3}' 2>/dev/null || echo "")
        if [ -n "$DOCKER_IMAGES" ]; then
            echo "$DOCKER_IMAGES" | xargs -r docker rmi -f 2>/dev/null || true
        fi
        
        # Remove k3s containerd images
        echo "Rimozione immagini k3s containerd CRM..."
        K3S_IMAGES=$(sudo k3s ctr images list | grep -E "(crm-|postgres)" | awk '{print $1}' 2>/dev/null || echo "")
        if [ -n "$K3S_IMAGES" ]; then
            echo "$K3S_IMAGES" | while read img; do
                sudo k3s ctr images rm "$img" 2>/dev/null || true
            done
        fi
        
        # Clean up dangling images
        echo "Pulizia immagini dangling..."
        docker image prune -f 2>/dev/null || true
        sudo k3s ctr images prune 2>/dev/null || true
        
        echo -e "${GREEN}✅ Cleanup immagini completato${NC}"
    else
        echo "Cleanup immagini Docker saltato"
    fi
}

# Function to verify complete cleanup
verify_complete_cleanup() {
    echo -e "${BLUE}🔍 Verifica cleanup OMNICOMPRENSIVO...${NC}"
    
    # Check namespace
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE ancora presente${NC}"
    else
        echo -e "${GREEN}✅ Namespace $NAMESPACE rimosso${NC}"
    fi
    
    # Check for orphaned PVs
    ORPHANED_PVS=$($KUBECTL_CMD get pv 2>/dev/null | grep -E "(crm-|postgres)" | wc -l || echo "0")
    if [ "$ORPHANED_PVS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Trovati $ORPHANED_PVS PV CRM orfani${NC}"
        $KUBECTL_CMD get pv | grep -E "(crm-|postgres)" || true
    else
        echo -e "${GREEN}✅ Nessun PV CRM orfano${NC}"
    fi
    
    # Check cluster status
    echo ""
    echo "Stato cluster post-cleanup:"
    echo "Namespaces disponibili:"
    $KUBECTL_CMD get namespaces | head -10
    
    echo ""
    echo "Storage classes disponibili:"
    $KUBECTL_CMD get storageclass
    
    echo ""
    echo "Nodes cluster:"
    $KUBECTL_CMD get nodes
    
    echo -e "${GREEN}✅ Verifica cleanup completata${NC}"
}

# Function to show post-cleanup information
show_post_cleanup_info() {
    echo ""
    echo -e "${PURPLE}=== 📋 CLEANUP OMNICOMPRENSIVO COMPLETATO ===${NC}"
    echo ""
    echo -e "${GREEN}🎯 Riassunto cleanup:${NC}"
    echo "   🗑️  Namespace '$NAMESPACE' completamente rimosso"
    echo "   🗑️  Tutti i workload CRM cancellati"
    echo "   🗑️  Storage e dati CRM cancellati"
    echo "   🗑️  Secrets e configurazioni rimosse"
    echo "   🗑️  Endpoints appesi rimossi"
    echo "   🗑️  Persistent Volumes CRM orfani cancellati"
    echo "   🗑️  Immagini Docker/k3s CRM rimosse (se scelto)"
    echo ""
    
    if [ -n "${BACKUP_DIR:-}" ]; then
        echo -e "${GREEN}💾 Backup salvato in:${NC}"
        echo "   $BACKUP_DIR"
        echo ""
        echo -e "${BLUE}Per ripristinare dal backup:${NC}"
        echo "   1. cd $BACKUP_DIR"
        echo "   2. kubectl create namespace $NAMESPACE"
        echo "   3. kubectl apply -f secrets.yaml"
        echo "   4. kubectl apply -f configmaps.yaml"
        echo "   5. kubectl apply -f pvc-resources.yaml"
        echo "   6. kubectl apply -f all-resources.yaml"
        echo ""
    fi
    
    echo -e "${GREEN}🚀 Per ridistribuire CRM completamente pulito:${NC}"
    echo "   cd ~/Claude/devops-pipeline-fase-6"
    echo "   ./deploy-k8s.sh start"
    echo ""
    
    echo -e "${GREEN}🔍 Per verificare stato cluster:${NC}"
    echo "   kubectl get namespaces"
    echo "   kubectl get pv"
    echo "   kubectl get storageclass"
    echo "   kubectl get nodes"
    echo ""
    
    echo -e "${CYAN}Cluster pronto per deployment pulito! 🚀${NC}"
}

# Main execution
main() {
    local action=${1:-interactive}
    
    case $action in
        --omnicomprensivo)
            echo -e "${RED}🚨 CLEANUP OMNICOMPRENSIVO AUTOMATICO${NC}"
            backup_data
            force_terminate_workloads
            delete_all_resources
            delete_storage_omnicomprensivo
            delete_namespace_final
            cleanup_docker_images_omnicomprensivo
            verify_complete_cleanup
            show_post_cleanup_info
            ;;
        --no-backup)
            echo -e "${YELLOW}⚠️  CLEANUP OMNICOMPRENSIVO SENZA BACKUP${NC}"
            confirm_cleanup
            force_terminate_workloads
            delete_all_resources
            delete_storage_omnicomprensivo
            delete_namespace_final
            cleanup_docker_images_omnicomprensivo
            verify_complete_cleanup
            show_post_cleanup_info
            ;;
        --fix-deployments)
            echo -e "${BLUE}🔧 FIX STUCK DEPLOYMENTS MODE${NC}"
            fix_stuck_deployments
            echo -e "${GREEN}✅ Deployment fix completato!${NC}"
            ;;
        --help)
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  (no option)          Cleanup omnicomprensivo interattivo con backup"
            echo "  --omnicomprensivo    Cleanup omnicomprensivo automatico con backup"
            echo "  --no-backup          Cleanup omnicomprensivo senza backup"
            echo "  --fix-deployments    Fix deployment stuck solamente"
            echo "  --help               Mostra questo aiuto"
            echo ""
            echo "CLEANUP OMNICOMPRENSIVO include:"
            echo "  • Tutti i workload (pod, deployment, service, etc.)"
            echo "  • Persistent Storage (PERDITA DATI!)"
            echo "  • Secrets, ConfigMaps, ServiceAccounts"
            echo "  • Endpoints appesi e orfani"
            echo "  • ReplicaSets bloccati"
            echo "  • Persistent Volumes CRM orfani"
            echo "  • Immagini Docker/k3s CRM (opzionale)"
            echo "  • Namespace completo"
            echo ""
            echo "Examples:"
            echo "  $0                      # Cleanup interattivo"
            echo "  $0 --omnicomprensivo   # Cleanup automatico"
            echo "  $0 --no-backup         # Cleanup senza backup"
            echo ""
            exit 0
            ;;
        *)
            # Interactive mode (default) - OMNICOMPRENSIVO
            confirm_cleanup
            backup_data
            force_terminate_workloads
            delete_all_resources
            delete_storage_omnicomprensivo
            delete_namespace_final
            cleanup_docker_images_omnicomprensivo
            verify_complete_cleanup
            show_post_cleanup_info
            ;;
    esac
    
    echo -e "${GREEN}✅ Cleanup omnicomprensivo completato con successo!${NC}"
}

# Execute main function
main "$@"
