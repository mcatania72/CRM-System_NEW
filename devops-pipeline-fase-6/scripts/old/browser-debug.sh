#!/bin/bash

# FASE 6: Script per debug approfondito accesso browser
# Verifica binding porte e accesso esterno specifico

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

echo -e "${BLUE}=== 🔍 FASE 6: Debug Avanzato Accesso Browser ===${NC}"
echo "DEV_VM IP: $DEV_VM_IP"
echo ""

# Function to check k3s NodePort binding
check_k3s_nodeport_binding() {
    echo -e "${BLUE}🔌 Verifica binding NodePort k3s...${NC}"
    
    # Check if k3s is listening on NodePorts
    echo "Processi k3s in ascolto:"
    sudo netstat -tlnp | grep k3s || echo "Nessun processo k3s trovato in netstat"
    echo ""
    
    # Check specific NodePort binding
    echo "Binding specifico porte 30002/30003:"
    sudo ss -tlnp | grep -E ":30002|:30003" || echo "Porte NodePort non in binding diretto"
    echo ""
    
    # Check if kube-proxy is running
    echo "Stato kube-proxy:"
    sudo systemctl status k3s | grep -E "(kube-proxy|Active)" || echo "Informazioni kube-proxy non disponibili"
    echo ""
    
    # Check k3s service binding
    echo "Servizi k3s attivi:"
    sudo ss -tlnp | grep ":6443\|:10250" || echo "Servizi k3s non visibili"
    echo ""
}

# Function to test with different methods
test_access_methods() {
    echo -e "${BLUE}🧪 Test metodi di accesso diversi...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Get NodePort
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")
    
    echo "Frontend Port: $FRONTEND_PORT"
    echo ""
    
    # Test 1: Direct curl verbose
    echo "Test 1: Curl verbose locale"
    curl -v "http://localhost:$FRONTEND_PORT" 2>&1 | head -20
    echo ""
    
    # Test 2: Curl with specific IP
    echo "Test 2: Curl con IP specifico"
    curl -v "http://$DEV_VM_IP:$FRONTEND_PORT" 2>&1 | head -20
    echo ""
    
    # Test 3: Wget test
    echo "Test 3: Wget test"
    wget -O - "http://$DEV_VM_IP:$FRONTEND_PORT" 2>&1 | head -10
    echo ""
    
    # Test 4: Telnet test
    echo "Test 4: Telnet test porta"
    timeout 5 telnet $DEV_VM_IP $FRONTEND_PORT 2>/dev/null && echo "Porta raggiungibile" || echo "Porta non raggiungibile"
    echo ""
}

# Function to check k3s iptables rules
check_iptables_rules() {
    echo -e "${BLUE}🔥 Verifica regole iptables k3s...${NC}"
    
    echo "Regole iptables per NodePort (30002/30003):"
    sudo iptables -t nat -L -n | grep -E "30002|30003" || echo "Nessuna regola NAT per NodePort"
    echo ""
    
    echo "Regole iptables FORWARD:"
    sudo iptables -L FORWARD -n | head -10
    echo ""
    
    echo "Regole iptables INPUT per porte 30000-31000:"
    sudo iptables -L INPUT -n | grep -E "300[0-9][0-9]|310[0-9][0-9]" || echo "Nessuna regola INPUT per NodePort range"
    echo ""
}

# Function to check pod endpoints directly
check_pod_endpoints() {
    echo -e "${BLUE}🎯 Test accesso diretto ai pod...${NC}"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE non esiste${NC}"
        return 1
    fi
    
    # Get pod IPs
    echo "Pod IPs frontend:"
    FRONTEND_IPS=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=frontend -o jsonpath='{.items[*].status.podIP}' 2>/dev/null || echo "")
    echo "$FRONTEND_IPS"
    echo ""
    
    if [ -n "$FRONTEND_IPS" ]; then
        for ip in $FRONTEND_IPS; do
            echo "Test diretto pod $ip:80"
            curl -s -I "http://$ip" 2>/dev/null && echo "✅ Pod $ip risponde" || echo "❌ Pod $ip non risponde"
        done
    fi
    echo ""
    
    # Test service ClusterIP
    echo "Test service ClusterIP:"
    FRONTEND_CLUSTER_IP=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [ -n "$FRONTEND_CLUSTER_IP" ] && [ "$FRONTEND_CLUSTER_IP" != "None" ]; then
        echo "Frontend ClusterIP: $FRONTEND_CLUSTER_IP"
        curl -s -I "http://$FRONTEND_CLUSTER_IP" 2>/dev/null && echo "✅ ClusterIP risponde" || echo "❌ ClusterIP non risponde"
    else
        echo "ClusterIP: None (headless service)"
    fi
    echo ""
}

# Function to check from outside k3s
test_external_access() {
    echo -e "${BLUE}🌍 Test accesso esterno (simulazione browser)...${NC}"
    
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")
    
    # Test with different host headers
    echo "Test 1: Accesso con Host header standard"
    curl -H "Host: $DEV_VM_IP" -I "http://$DEV_VM_IP:$FRONTEND_PORT" 2>/dev/null && echo "✅ OK" || echo "❌ FAIL"
    
    echo "Test 2: Accesso con User-Agent browser"
    curl -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -I "http://$DEV_VM_IP:$FRONTEND_PORT" 2>/dev/null && echo "✅ OK" || echo "❌ FAIL"
    
    echo "Test 3: Accesso con Accept header HTML"
    curl -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -I "http://$DEV_VM_IP:$FRONTEND_PORT" 2>/dev/null && echo "✅ OK" || echo "❌ FAIL"
    
    echo "Test 4: GET request completa"
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DEV_VM_IP:$FRONTEND_PORT")
    echo "HTTP Response Code: $RESPONSE"
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ Server risponde correttamente${NC}"
        echo "Problema potrebbe essere lato client/browser"
    else
        echo -e "${RED}❌ Server risponde con errore: $RESPONSE${NC}"
    fi
    echo ""
}

# Function to create port forward as alternative
create_port_forward() {
    echo -e "${BLUE}🔄 Creazione port-forward alternativo...${NC}"
    
    echo "Creando port-forward per frontend su porta 8080..."
    echo "Comando: kubectl port-forward -n $NAMESPACE svc/frontend-service 8080:80"
    echo ""
    echo "Dopo aver eseguito il comando sopra in un'altra sessione,"
    echo "dovresti poter accedere a: http://$DEV_VM_IP:8080"
    echo ""
    echo "Per backend su porta 8081:"
    echo "kubectl port-forward -n $NAMESPACE svc/backend-service 8081:4001"
    echo "Accesso: http://$DEV_VM_IP:8081/api"
    echo ""
}

# Function to show alternative access methods
show_alternatives() {
    echo -e "${BLUE}🛠️  Metodi di accesso alternativi...${NC}"
    
    echo "1. Port Forward (raccomandato per test):"
    echo "   kubectl port-forward -n $NAMESPACE svc/frontend-service 8080:80"
    echo "   Accesso: http://$DEV_VM_IP:8080"
    echo ""
    
    echo "2. Proxy kubectl:"
    echo "   kubectl proxy --address='0.0.0.0' --accept-hosts='.*'"
    echo "   Accesso: http://$DEV_VM_IP:8001/api/v1/namespaces/$NAMESPACE/services/frontend-service/proxy/"
    echo ""
    
    echo "3. Ingress Controller (per production):"
    echo "   Configurare Traefik/Nginx Ingress"
    echo ""
    
    echo "4. LoadBalancer service (se supportato):"
    echo "   Cambiare type da NodePort a LoadBalancer"
    echo ""
}

# Function to fix k3s NodePort issues
fix_k3s_nodeport() {
    echo -e "${BLUE}🔧 Fix problemi NodePort k3s...${NC}"
    
    echo "1. Restart k3s per reset iptables rules..."
    sudo systemctl restart k3s
    
    echo "Aspettando k3s restart..."
    sleep 15
    
    echo "2. Verifica che k3s sia tornato attivo..."
    sudo systemctl status k3s --no-pager
    echo ""
    
    echo "3. Verifica che i pod siano tornati running..."
    $KUBECTL_CMD get pods -n $NAMESPACE
    echo ""
    
    echo "4. Test accesso dopo restart..."
    FRONTEND_PORT=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")
    curl -I "http://$DEV_VM_IP:$FRONTEND_PORT" 2>/dev/null && echo "✅ Accesso OK dopo restart" || echo "❌ Problema persiste"
    echo ""
}

# Main execution
main() {
    local command=${1:-full}
    
    case $command in
        binding)
            check_k3s_nodeport_binding
            ;;
        test)
            test_access_methods
            ;;
        iptables)
            check_iptables_rules
            ;;
        pods)
            check_pod_endpoints
            ;;
        external)
            test_external_access
            ;;
        portforward)
            create_port_forward
            ;;
        alternatives)
            show_alternatives
            ;;
        fix)
            fix_k3s_nodeport
            ;;
        full)
            check_k3s_nodeport_binding
            test_access_methods
            check_iptables_rules
            test_external_access
            show_alternatives
            ;;
        help|--help|-h)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  full         Debug completo (default)"
            echo "  binding      Verifica binding NodePort k3s"
            echo "  test         Test metodi accesso diversi"
            echo "  iptables     Verifica regole iptables"
            echo "  pods         Test accesso diretto pod"
            echo "  external     Test accesso esterno"
            echo "  portforward  Guida port-forward alternativo"
            echo "  alternatives Mostra metodi accesso alternativi"
            echo "  fix          Fix problemi NodePort k3s"
            echo "  help         Mostra questo aiuto"
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
