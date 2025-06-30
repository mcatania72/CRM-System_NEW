#!/bin/bash

# FASE 6: Script per debug logs e troubleshooting
# Raccoglie logs e informazioni di debug per troubleshooting

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="crm-system"
KUBECTL_CMD="kubectl"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 🔍 FASE 6: Debug e Troubleshooting ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Function to show pod logs
show_logs() {
    local component=${1:-all}
    local lines=${2:-50}
    
    echo -e "${BLUE}📋 Logs per componente: $component${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    case $component in
        postgres|db)
            echo -e "${YELLOW}=== PostgreSQL Logs ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=postgres -n $NAMESPACE 2>/dev/null || echo "PostgreSQL logs non disponibili"
            ;;
        backend|api)
            echo -e "${YELLOW}=== Backend Logs ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=backend -n $NAMESPACE 2>/dev/null || echo "Backend logs non disponibili"
            ;;
        frontend|web)
            echo -e "${YELLOW}=== Frontend Logs ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=frontend -n $NAMESPACE 2>/dev/null || echo "Frontend logs non disponibili"
            ;;
        all|*)
            echo -e "${YELLOW}=== PostgreSQL Logs (ultimi $lines) ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=postgres -n $NAMESPACE 2>/dev/null || echo "PostgreSQL non disponibile"
            echo ""
            echo -e "${YELLOW}=== Backend Logs (ultimi $lines) ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=backend -n $NAMESPACE 2>/dev/null || echo "Backend non disponibile"
            echo ""
            echo -e "${YELLOW}=== Frontend Logs (ultimi $lines) ===${NC}"
            $KUBECTL_CMD logs --tail=$lines -l app=frontend -n $NAMESPACE 2>/dev/null || echo "Frontend non disponibile"
            ;;
    esac
}

# Function to show pod status
show_status() {
    echo -e "${BLUE}📊 Status completo deployments${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    echo -e "${GREEN}📦 Deployments:${NC}"
    $KUBECTL_CMD get deployments -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}🏃 Pods:${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}🔗 Services:${NC}"
    $KUBECTL_CMD get services -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}🔗 Endpoints:${NC}"
    $KUBECTL_CMD get endpoints -n $NAMESPACE
    echo ""
    
    echo -e "${GREEN}💾 Storage:${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE
    echo ""
}

# Function to describe problematic pods
describe_problems() {
    echo -e "${BLUE}🔍 Analisi pod con problemi${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Find problematic pods
    PROBLEM_PODS=$($KUBECTL_CMD get pods -n $NAMESPACE --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull|Pending)" | awk '{print $1}' || echo "")
    
    if [ -n "$PROBLEM_PODS" ]; then
        echo -e "${YELLOW}Pod con problemi trovati:${NC}"
        echo "$PROBLEM_PODS"
        echo ""
        
        echo "$PROBLEM_PODS" | while read pod; do
            if [ -n "$pod" ]; then
                echo -e "${YELLOW}=== Dettagli pod: $pod ===${NC}"
                $KUBECTL_CMD describe pod $pod -n $NAMESPACE
                echo ""
                echo -e "${YELLOW}=== Logs pod: $pod ===${NC}"
                $KUBECTL_CMD logs $pod -n $NAMESPACE --tail=20 2>/dev/null || echo "Logs non disponibili"
                echo ""
                echo "================================="
                echo ""
            fi
        done
    else
        echo -e "${GREEN}✅ Nessun pod con problemi evidenti${NC}"
    fi
}

# Function to check connectivity
check_connectivity() {
    echo -e "${BLUE}🌐 Test connettività interna${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Check PostgreSQL connectivity
    POSTGRES_POD=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ] && [ "$POSTGRES_POD" != "<no value>" ]; then
        echo -e "${YELLOW}=== Test PostgreSQL ===${NC}"
        echo "Pod PostgreSQL: $POSTGRES_POD"
        
        # Test database connection
        echo "Test connessione database..."
        $KUBECTL_CMD exec $POSTGRES_POD -n $NAMESPACE -- pg_isready -U postgres -d crm 2>/dev/null && {
            echo -e "${GREEN}✅ Database connettibile${NC}"
        } || {
            echo -e "${RED}❌ Database non connettibile${NC}"
        }
        
        # Test service resolution
        echo "Test risoluzione service postgres-service..."
        $KUBECTL_CMD exec $POSTGRES_POD -n $NAMESPACE -- nslookup postgres-service 2>/dev/null && {
            echo -e "${GREEN}✅ Service DNS risolve${NC}"
        } || {
            echo -e "${RED}❌ Service DNS non risolve${NC}"
        }
    else
        echo -e "${RED}❌ Nessun pod PostgreSQL trovato${NC}"
    fi
    
    echo ""
    
    # Check backend connectivity
    BACKEND_POD=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_POD" ] && [ "$BACKEND_POD" != "<no value>" ]; then
        echo -e "${YELLOW}=== Test Backend ===${NC}"
        echo "Pod Backend: $BACKEND_POD"
        
        # Test backend health
        echo "Test backend health endpoint..."
        $KUBECTL_CMD exec $BACKEND_POD -n $NAMESPACE -- curl -f http://localhost:4001/api/health 2>/dev/null && {
            echo -e "${GREEN}✅ Backend health OK${NC}"
        } || {
            echo -e "${RED}❌ Backend health fallito${NC}"
        }
    else
        echo -e "${RED}❌ Nessun pod Backend pronto${NC}"
    fi
}

# Function to fix common issues
auto_fix() {
    echo -e "${BLUE}🔧 Auto-fix problemi comuni${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Fix 1: Restart crashed pods
    echo "Fix 1: Restart pod crashati..."
    CRASHED_PODS=$($KUBECTL_CMD get pods -n $NAMESPACE --no-headers | grep -E "(Error|CrashLoopBackOff)" | awk '{print $1}' || echo "")
    
    if [ -n "$CRASHED_PODS" ]; then
        echo "Pod crashati trovati: $CRASHED_PODS"
        echo "$CRASHED_PODS" | while read pod; do
            echo "Restarting pod: $pod"
            $KUBECTL_CMD delete pod $pod -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
        done
        echo -e "${GREEN}✅ Pod crashati riavviati${NC}"
    else
        echo "Nessun pod crashato trovato"
    fi
    
    echo ""
    
    # Fix 2: Check and reimport images if needed
    echo "Fix 2: Verifica immagini..."
    if command -v ./scripts/manage-images.sh &>/dev/null; then
        ./scripts/manage-images.sh check || {
            echo "Reimport immagini necessario..."
            ./scripts/manage-images.sh import
        }
    else
        echo "Script manage-images.sh non trovato"
    fi
    
    echo ""
    
    # Fix 3: Restart deployments
    echo "Fix 3: Restart deployments non healthy..."
    $KUBECTL_CMD rollout restart deployment/backend -n $NAMESPACE 2>/dev/null || true
    $KUBECTL_CMD rollout restart deployment/frontend -n $NAMESPACE 2>/dev/null || true
    
    echo -e "${GREEN}✅ Auto-fix completato${NC}"
}

# Function to generate debug report
generate_report() {
    local report_file="$HOME/crm-debug-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo -e "${BLUE}📄 Generazione report debug...${NC}"
    echo "File: $report_file"
    echo ""
    
    {
        echo "=== CRM Kubernetes Debug Report ==="
        echo "Generato: $(date)"
        echo "Hostname: $(hostname)"
        echo "Namespace: $NAMESPACE"
        echo ""
        
        echo "=== Cluster Info ==="
        $KUBECTL_CMD cluster-info 2>/dev/null || echo "Cluster info non disponibile"
        echo ""
        
        echo "=== Nodes ==="
        $KUBECTL_CMD get nodes -o wide 2>/dev/null || echo "Nodes info non disponibile"
        echo ""
        
        echo "=== Namespace Resources ==="
        $KUBECTL_CMD get all -n $NAMESPACE -o wide 2>/dev/null || echo "Namespace resources non disponibili"
        echo ""
        
        echo "=== Pod Details ==="
        $KUBECTL_CMD describe pods -n $NAMESPACE 2>/dev/null || echo "Pod details non disponibili"
        echo ""
        
        echo "=== Recent Events ==="
        $KUBECTL_CMD get events -n $NAMESPACE --sort-by='.lastTimestamp' 2>/dev/null || echo "Events non disponibili"
        echo ""
        
        echo "=== Logs ==="
        echo "--- PostgreSQL ---"
        $KUBECTL_CMD logs -l app=postgres -n $NAMESPACE --tail=50 2>/dev/null || echo "PostgreSQL logs non disponibili"
        echo ""
        echo "--- Backend ---"
        $KUBECTL_CMD logs -l app=backend -n $NAMESPACE --tail=50 2>/dev/null || echo "Backend logs non disponibili"
        echo ""
        echo "--- Frontend ---"
        $KUBECTL_CMD logs -l app=frontend -n $NAMESPACE --tail=50 2>/dev/null || echo "Frontend logs non disponibili"
        
    } > "$report_file"
    
    echo -e "${GREEN}✅ Report generato: $report_file${NC}"
}

# Main execution
main() {
    local command=${1:-status}
    local component=${2:-all}
    local lines=${3:-50}
    
    case $command in
        logs)
            show_logs "$component" "$lines"
            ;;
        status)
            show_status
            ;;
        describe)
            describe_problems
            ;;
        connectivity)
            check_connectivity
            ;;
        fix)
            auto_fix
            ;;
        report)
            generate_report
            ;;
        all)
            show_status
            echo ""
            describe_problems
            echo ""
            show_logs all 30
            ;;
        help|--help|-h)
            echo "Usage: $0 <command> [component] [lines]"
            echo ""
            echo "Commands:"
            echo "  status        Mostra status generale (default)"
            echo "  logs [comp]   Mostra logs componente (postgres|backend|frontend|all)"
            echo "  describe      Analizza pod con problemi"
            echo "  connectivity  Test connettività interna"
            echo "  fix           Auto-fix problemi comuni"
            echo "  report        Genera report debug completo"
            echo "  all           Status + describe + logs"
            echo "  help          Mostra questo aiuto"
            echo ""
            echo "Examples:"
            echo "  $0 logs frontend    # Logs frontend"
            echo "  $0 logs backend 100 # 100 righe logs backend"
            echo "  $0 describe         # Analizza problemi"
            echo "  $0 fix              # Auto-fix"
            ;;
        *)
            echo -e "${RED}❌ Comando sconosciuto: $command${NC}"
            echo "Usa '$0 help' per informazioni"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
