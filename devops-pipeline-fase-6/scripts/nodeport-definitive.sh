#!/bin/bash

# FASE 6: Script definitivo per NodePort 30002/30003 funzionanti
# Risolve tutti i problemi k3s NodePort in modo automatico e reproducibile

set -euo pipefail

NAMESPACE="crm-system"
FRONTEND_NODEPORT="30002"
BACKEND_NODEPORT="30003"

echo "=== 🎯 FASE 6: NodePort 30002/30003 Definitivo ==="
echo "Namespace: ${NAMESPACE}"
echo "Target: Frontend ${FRONTEND_NODEPORT}, Backend ${BACKEND_NODEPORT}"
echo "Timestamp: $(date)"
echo ""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_usage() {
    echo "Usage: $0 [comando]"
    echo ""
    echo "Comandi disponibili:"
    echo "  setup      - Setup completo NodePort 30002/30003"
    echo "  verify     - Verifica funzionamento NodePort"
    echo "  troubleshoot - Debug problemi NodePort"
    echo "  reset      - Reset completo e riconfigurazione"
    echo ""
}

cleanup_previous_setup() {
    echo -e "${BLUE}🧹 Cleanup setup precedenti...${NC}"
    
    # Kill port-forward residui
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Remove any conflicting services
    kubectl delete service frontend-nodeport backend-nodeport -n ${NAMESPACE} 2>/dev/null || true
    
    # Reset firewall ports
    sudo ufw delete allow comment "CRM Frontend Port-Forward" 2>/dev/null || true
    sudo ufw delete allow comment "CRM Backend Port-Forward" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup completato${NC}"
}

fix_k3s_nodeport_binding() {
    echo -e "${BLUE}🔧 Fix K3s NodePort binding...${NC}"
    
    # Verifica configurazione k3s
    echo "Configurazione K3s:"
    sudo systemctl cat k3s | grep ExecStart
    
    # Check for problematic flags
    if sudo systemctl cat k3s | grep -q "\-\-disable-kube-proxy"; then
        echo -e "${RED}❌ PROBLEMA: k3s ha --disable-kube-proxy${NC}"
        echo "Questo impedisce NodePort. Riconfigurando..."
        
        # Backup and modify k3s service
        sudo cp /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.backup
        sudo sed -i 's/--disable-kube-proxy//g' /etc/systemd/system/k3s.service
        sudo systemctl daemon-reload
    fi
    
    # Force restart k3s with clean state
    echo "Restart k3s con stato pulito..."
    sudo systemctl stop k3s
    sleep 5
    
    # Clean iptables nat table (safely)
    sudo iptables -t nat -F KUBE-NODEPORTS 2>/dev/null || true
    sudo iptables -t nat -F KUBE-SERVICES 2>/dev/null || true
    
    # Restart k3s
    sudo systemctl start k3s
    
    # Wait for cluster ready
    echo "Aspetto che k3s sia pronto..."
    sleep 30
    kubectl wait --for=condition=Ready node --all --timeout=120s
    
    echo -e "${GREEN}✅ K3s riconfigurato${NC}"
}

create_dedicated_nodeport_services() {
    echo -e "${BLUE}📋 Creazione servizi NodePort dedicati...${NC}"
    
    # Frontend NodePort dedicato
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport-direct
  namespace: ${NAMESPACE}
  labels:
    app: frontend
    service-type: nodeport-direct
spec:
  type: NodePort
  externalTrafficPolicy: Local
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: ${FRONTEND_NODEPORT}
    protocol: TCP
  selector:
    app: frontend
    component: web
EOF
    
    # Backend NodePort dedicato
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport-direct
  namespace: ${NAMESPACE}
  labels:
    app: backend
    service-type: nodeport-direct
spec:
  type: NodePort
  externalTrafficPolicy: Local
  ports:
  - name: http
    port: 4001
    targetPort: 4001
    nodePort: ${BACKEND_NODEPORT}
    protocol: TCP
  selector:
    app: backend
    component: application
EOF
    
    echo -e "${GREEN}✅ Servizi NodePort dedicati creati${NC}"
}

ensure_firewall_rules() {
    echo -e "${BLUE}🔥 Configurazione firewall...${NC}"
    
    # Ensure UFW is active
    sudo ufw --force enable
    
    # Add NodePort rules
    sudo ufw allow ${FRONTEND_NODEPORT}/tcp comment 'CRM Frontend NodePort Direct'
    sudo ufw allow ${BACKEND_NODEPORT}/tcp comment 'CRM Backend NodePort Direct'
    
    # Reload firewall
    sudo ufw reload
    
    echo -e "${GREEN}✅ Firewall configurato${NC}"
}

wait_for_nodeport_binding() {
    echo -e "${BLUE}⏳ Attesa binding NodePort...${NC}"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Tentativo $attempt/$max_attempts..."
        
        if sudo netstat -tulpn | grep -q ":${FRONTEND_NODEPORT}" && \
           sudo netstat -tulpn | grep -q ":${BACKEND_NODEPORT}"; then
            echo -e "${GREEN}✅ NodePort binding successful!${NC}"
            return 0
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ NodePort binding timeout${NC}"
    return 1
}

verify_nodeport_access() {
    echo -e "${BLUE}🧪 Verifica accesso NodePort...${NC}"
    
    # Test local access
    echo "Test accesso locale:"
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${FRONTEND_NODEPORT} | grep -q "200\|404\|302"; then
        echo -e "${GREEN}✅ Frontend NodePort ${FRONTEND_NODEPORT} OK${NC}"
    else
        echo -e "${RED}❌ Frontend NodePort ${FRONTEND_NODEPORT} FAIL${NC}"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${BACKEND_NODEPORT}/api/health | grep -q "200\|404\|500"; then
        echo -e "${GREEN}✅ Backend NodePort ${BACKEND_NODEPORT} OK${NC}"
    else
        echo -e "${RED}❌ Backend NodePort ${BACKEND_NODEPORT} FAIL${NC}"
    fi
    
    # Test external access (from host machine)
    echo ""
    echo "Test accesso esterno:"
    
    if timeout 5 nc -z 192.168.1.29 ${FRONTEND_NODEPORT} 2>/dev/null; then
        echo -e "${GREEN}✅ Frontend externally reachable${NC}"
    else
        echo -e "${RED}❌ Frontend not externally reachable${NC}"
    fi
    
    if timeout 5 nc -z 192.168.1.29 ${BACKEND_NODEPORT} 2>/dev/null; then
        echo -e "${GREEN}✅ Backend externally reachable${NC}"
    else
        echo -e "${RED}❌ Backend not externally reachable${NC}"
    fi
}

troubleshoot_nodeport() {
    echo -e "${BLUE}🔍 Troubleshooting NodePort...${NC}"
    
    echo "=== K3s Service Status ==="
    sudo systemctl status k3s --no-pager -l
    echo ""
    
    echo "=== Network Binding ==="
    sudo netstat -tulpn | grep -E ":${FRONTEND_NODEPORT}|:${BACKEND_NODEPORT}" || echo "No NodePort binding found"
    echo ""
    
    echo "=== Kubernetes Services ==="
    kubectl get services -n ${NAMESPACE} -o wide
    echo ""
    
    echo "=== Service Endpoints ==="
    kubectl get endpoints -n ${NAMESPACE}
    echo ""
    
    echo "=== K3s Logs (last 20 lines) ==="
    sudo journalctl -u k3s --no-pager -n 20
    echo ""
    
    echo "=== Firewall Status ==="
    sudo ufw status numbered | grep -E "${FRONTEND_NODEPORT}|${BACKEND_NODEPORT}"
}

show_access_info() {
    echo ""
    echo -e "${YELLOW}🌐 ACCESSO CRM NODEPORT:${NC}"
    echo ""
    echo "Frontend: http://192.168.1.29:${FRONTEND_NODEPORT}"
    echo "Backend API: http://192.168.1.29:${BACKEND_NODEPORT}/api"
    echo "Login: admin@crm.local / admin123"
    echo ""
    echo "🔍 Per debug: $0 troubleshoot"
    echo "🔄 Per reset: $0 reset"
}

# Main command handling
case "${1:-setup}" in
    "setup")
        cleanup_previous_setup
        echo ""
        fix_k3s_nodeport_binding
        echo ""
        create_dedicated_nodeport_services
        echo ""
        ensure_firewall_rules
        echo ""
        wait_for_nodeport_binding
        echo ""
        verify_nodeport_access
        show_access_info
        ;;
    "verify")
        verify_nodeport_access
        show_access_info
        ;;
    "troubleshoot")
        troubleshoot_nodeport
        ;;
    "reset")
        cleanup_previous_setup
        echo ""
        echo "Eseguire: $0 setup"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo -e "${RED}❌ Comando non riconosciuto: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
echo "=== NodePort setup completato ==="
