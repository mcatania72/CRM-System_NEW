#!/bin/bash

# FASE 6: Script per troubleshooting accesso esterno
# Verifica connettività da browser esterno

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
DEV_VM_IP="192.168.1.29"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 🌐 FASE 6: Troubleshooting Accesso Browser ===${NC}"
echo "DEV_VM IP: $DEV_VM_IP"
echo "Namespace: $NAMESPACE"
echo ""

# Function to check firewall status
check_firewall() {
    echo -e "${BLUE}🔥 Verifica Firewall Ubuntu...${NC}"
    
    # Check UFW status
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")
    echo "UFW Status: $UFW_STATUS"
    
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo "UFW è attivo, verificando regole..."
        
        # Check specific ports
        echo "Regole per porta 30002 (Frontend):"
        sudo ufw status numbered | grep "30002" || echo "Nessuna regola per 30002"
        
        echo "Regole per porta 30003 (Backend):"
        sudo ufw status numbered | grep "30003" || echo "Nessuna regola per 30003"
        
        # Check if ports are allowed
        if sudo ufw status | grep -q "30002"; then
            echo -e "${GREEN}✅ Porta 30002 configurata in UFW${NC}"
        else
            echo -e "${RED}❌ Porta 30002 NON configurata in UFW${NC}"
            echo "Per aprire: sudo ufw allow 30002/tcp"
        fi
        
        if sudo ufw status | grep -q "30003"; then
            echo -e "${GREEN}✅ Porta 30003 configurata in UFW${NC}"
        else
            echo -e "${RED}❌ Porta 30003 NON configurata in UFW${NC}"
            echo "Per aprire: sudo ufw allow 30003/tcp"
        fi
    else
        echo -e "${GREEN}✅ UFW disattivo - nessun blocco firewall${NC}"
    fi
    
    echo ""
}

# Function to check node ports
check_nodeports() {
    echo -e "${BLUE}🔌 Verifica NodePort Services...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Get NodePort info
    echo "Services NodePort:"
    $KUBECTL_CMD get services -n $NAMESPACE -o wide
    echo ""
    
    # Get specific ports
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    BACKEND_PORT=$($KUBECTL_CMD get svc backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    
    echo "Frontend NodePort: $FRONTEND_PORT"
    echo "Backend NodePort: $BACKEND_PORT"
    echo ""
    
    # Verify ports are as expected
    if [ "$FRONTEND_PORT" = "30002" ]; then
        echo -e "${GREEN}✅ Frontend su porta corretta: 30002${NC}"
    else
        echo -e "${YELLOW}⚠️  Frontend su porta diversa: $FRONTEND_PORT${NC}"
    fi
    
    if [ "$BACKEND_PORT" = "30003" ]; then
        echo -e "${GREEN}✅ Backend su porta corretta: 30003${NC}"
    else
        echo -e "${YELLOW}⚠️  Backend su porta diversa: $BACKEND_PORT${NC}"
    fi
    
    echo ""
}

# Function to test local connectivity
test_local_connectivity() {
    echo -e "${BLUE}🧪 Test connettività locale (dalla DEV_VM)...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Get actual ports
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")
    BACKEND_PORT=$($KUBECTL_CMD get svc backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30003")
    
    echo "Test Frontend (porta $FRONTEND_PORT)..."
    if curl -s -I "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend risponde su localhost:$FRONTEND_PORT${NC}"
    else
        echo -e "${RED}❌ Frontend NON risponde su localhost:$FRONTEND_PORT${NC}"
    fi
    
    echo "Test Frontend su IP DEV_VM..."
    if curl -s -I "http://$DEV_VM_IP:$FRONTEND_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend risponde su $DEV_VM_IP:$FRONTEND_PORT${NC}"
    else
        echo -e "${RED}❌ Frontend NON risponde su $DEV_VM_IP:$FRONTEND_PORT${NC}"
    fi
    
    echo ""
    echo "Test Backend (porta $BACKEND_PORT)..."
    if curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend risponde su localhost:$BACKEND_PORT${NC}"
    else
        echo -e "${RED}❌ Backend NON risponde su localhost:$BACKEND_PORT${NC}"
    fi
    
    echo "Test Backend su IP DEV_VM..."
    if curl -s "http://$DEV_VM_IP:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend risponde su $DEV_VM_IP:$BACKEND_PORT${NC}"
    else
        echo -e "${RED}❌ Backend NON risponde su $DEV_VM_IP:$BACKEND_PORT${NC}"
    fi
    
    echo ""
}

# Function to check network interfaces
check_network_interfaces() {
    echo -e "${BLUE}🌐 Verifica interfacce di rete...${NC}"
    
    echo "Interfacce di rete attive:"
    ip addr show | grep -E "(inet.*global|^[0-9]+:)" | head -20
    echo ""
    
    echo "IP address configurati:"
    hostname -I
    echo ""
    
    echo "Verifica che $DEV_VM_IP sia attivo..."
    if ip addr show | grep -q "$DEV_VM_IP"; then
        echo -e "${GREEN}✅ IP $DEV_VM_IP configurato sulla VM${NC}"
    else
        echo -e "${RED}❌ IP $DEV_VM_IP NON trovato sulla VM${NC}"
        echo "IP attuali:"
        hostname -I
    fi
    
    echo ""
}

# Function to check processes listening on ports
check_listening_ports() {
    echo -e "${BLUE}👂 Verifica processi in ascolto su porte...${NC}"
    
    echo "Processi in ascolto su porte 30000-30010:"
    sudo netstat -tlnp | grep ":300" || echo "Nessun processo su porte 30xxx"
    echo ""
    
    echo "Verifica specifica porte NodePort:"
    sudo ss -tlnp | grep -E "(30002|30003)" || echo "Porte 30002/30003 non in ascolto"
    echo ""
}

# Function to auto-fix common issues
auto_fix_network() {
    echo -e "${BLUE}🔧 Auto-fix problemi di rete comuni...${NC}"
    
    # Check and fix firewall
    echo "1. Verifica e fix firewall..."
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")
    
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        if ! sudo ufw status | grep -q "30002"; then
            echo "Aprendo porta 30002 (Frontend)..."
            sudo ufw allow 30002/tcp comment 'CRM Frontend K8s'
        fi
        
        if ! sudo ufw status | grep -q "30003"; then
            echo "Aprendo porta 30003 (Backend)..."
            sudo ufw allow 30003/tcp comment 'CRM Backend K8s'
        fi
        
        echo "Firewall aggiornato:"
        sudo ufw status | grep -E "(30002|30003)"
    fi
    
    echo ""
    
    # Restart services if needed
    echo "2. Restart servizi se necessario..."
    
    # Check if pods are ready
    FRONTEND_READY=$($KUBECTL_CMD get deployment frontend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    BACKEND_READY=$($KUBECTL_CMD get deployment backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    
    if [ "$FRONTEND_READY" = "0" ]; then
        echo "Frontend non pronto, restart..."
        $KUBECTL_CMD rollout restart deployment/frontend -n $NAMESPACE
    fi
    
    if [ "$BACKEND_READY" = "0" ]; then
        echo "Backend non pronto, restart..."
        $KUBECTL_CMD rollout restart deployment/backend -n $NAMESPACE
    fi
    
    echo ""
    echo -e "${GREEN}✅ Auto-fix completato${NC}"
}

# Function to show access information
show_access_info() {
    echo -e "${BLUE}📋 Informazioni di accesso corrette...${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Get actual ports
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    BACKEND_PORT=$($KUBECTL_CMD get svc backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    
    echo -e "${GREEN}🎨 Frontend CRM:${NC}"
    echo "   URL: http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "   Porta: $FRONTEND_PORT"
    echo ""
    
    echo -e "${GREEN}🔌 Backend API:${NC}"
    echo "   URL: http://$DEV_VM_IP:$BACKEND_PORT/api"
    echo "   Health: http://$DEV_VM_IP:$BACKEND_PORT/api/health"
    echo "   Porta: $BACKEND_PORT"
    echo ""
    
    echo -e "${GREEN}🔑 Credenziali Login:${NC}"
    echo "   Email: admin@crm.local"
    echo "   Password: admin123"
    echo ""
    
    echo -e "${GREEN}🛠️  Troubleshooting:${NC}"
    echo "   Status: ./scripts/network-troubleshoot.sh status"
    echo "   Fix: ./scripts/network-troubleshoot.sh fix"
    echo "   Test: ./scripts/network-troubleshoot.sh test"
    echo ""
}

# Main execution
main() {
    local command=${1:-status}
    
    case $command in
        firewall)
            check_firewall
            ;;
        nodeports)
            check_nodeports
            ;;
        test)
            test_local_connectivity
            ;;
        network)
            check_network_interfaces
            ;;
        ports)
            check_listening_ports
            ;;
        fix)
            auto_fix_network
            echo ""
            echo "Dopo il fix, testa nuovamente:"
            test_local_connectivity
            ;;
        info)
            show_access_info
            ;;
        status|all)
            check_firewall
            check_nodeports
            check_network_interfaces
            test_local_connectivity
            check_listening_ports
            show_access_info
            ;;
        help|--help|-h)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  status      Verifica completa (default)"
            echo "  firewall    Verifica firewall UFW"
            echo "  nodeports   Verifica porte NodePort K8s"
            echo "  test        Test connettività locale"
            echo "  network     Verifica interfacce di rete"
            echo "  ports       Verifica processi in ascolto"
            echo "  fix         Auto-fix problemi comuni"
            echo "  info        Mostra info di accesso"
            echo "  help        Mostra questo aiuto"
            echo ""
            echo "Examples:"
            echo "  $0 status    # Verifica completa"
            echo "  $0 test      # Test connettività"
            echo "  $0 fix       # Auto-fix problemi"
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
