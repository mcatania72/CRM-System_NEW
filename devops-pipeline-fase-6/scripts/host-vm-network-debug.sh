#!/bin/bash

# FASE 6: Debug Network Host Windows ↔ DEV_VM
# Risolve problemi connettività tra host e VM

set -euo pipefail

NAMESPACE="crm-system"
DEV_VM_IP="192.168.1.29"
FRONTEND_PORT="30002"
BACKEND_PORT="30003"

echo "=== 🌐 FASE 6: Debug Network Host-VM ==="
echo "DEV_VM IP: ${DEV_VM_IP}"
echo "Ports: ${FRONTEND_PORT}, ${BACKEND_PORT}"
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
    echo "  status     - Verifica completa network host-vm"
    echo "  fix        - Fix automatico problemi network"
    echo "  expose     - Espone servizi con port-forward"
    echo "  firewall   - Debug firewall e iptables"
    echo "  vmware     - Fix specifici VMware networking"
    echo ""
}

check_vm_connectivity() {
    echo -e "${BLUE}🔍 Verifica connettività base host → VM...${NC}"
    
    # Test ping
    echo "Test ping VM..."
    if ping -c 3 ${DEV_VM_IP} >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Ping VM successful${NC}"
    else
        echo -e "${RED}❌ Ping VM failed - Problema rete base${NC}"
        return 1
    fi
    
    # Test SSH
    echo "Test SSH connectivity..."
    if timeout 5 nc -z ${DEV_VM_IP} 22 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SSH port reachable${NC}"
    else
        echo -e "${RED}❌ SSH port not reachable${NC}"
    fi
    
    # Test target ports
    echo "Test NodePort connectivity..."
    for port in ${FRONTEND_PORT} ${BACKEND_PORT}; do
        if timeout 5 nc -z ${DEV_VM_IP} ${port} >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Port ${port} reachable${NC}"
        else
            echo -e "${RED}❌ Port ${port} NOT reachable${NC}"
        fi
    done
}

check_vm_firewall() {
    echo -e "${BLUE}🔥 Verifica firewall VM...${NC}"
    
    echo "UFW Status:"
    sudo ufw status numbered || echo "UFW not active"
    echo ""
    
    echo "Iptables rules for target ports:"
    sudo iptables -L INPUT -n | grep -E "(${FRONTEND_PORT}|${BACKEND_PORT})" || echo "No specific iptables rules"
    echo ""
    
    echo "Listening ports:"
    sudo netstat -tulpn | grep -E ":${FRONTEND_PORT}|:${BACKEND_PORT}" || echo "Ports not listening"
}

check_k3s_nodeport() {
    echo -e "${BLUE}☸️ Verifica K3s NodePort binding...${NC}"
    
    # Check k3s process listening
    echo "K3s process listening on NodePorts:"
    sudo netstat -tulpn | grep -E ":${FRONTEND_PORT}|:${BACKEND_PORT}" || echo "No NodePort binding found"
    echo ""
    
    # Check services
    echo "Kubernetes Services:"
    kubectl get services -n ${NAMESPACE} -o wide
    echo ""
    
    # Check endpoints
    echo "Service Endpoints:"
    kubectl get endpoints -n ${NAMESPACE}
    echo ""
}

fix_vm_firewall() {
    echo -e "${BLUE}🔧 Fix VM Firewall...${NC}"
    
    # Ensure UFW allows NodePorts
    echo "Opening NodePort in UFW..."
    sudo ufw allow ${FRONTEND_PORT}/tcp comment 'CRM Frontend K8s NodePort'
    sudo ufw allow ${BACKEND_PORT}/tcp comment 'CRM Backend K8s NodePort'
    
    # Check if UFW is blocking
    sudo ufw --force enable
    echo ""
    
    # Reload UFW
    sudo ufw reload
    echo "✅ UFW configured"
}

fix_k3s_nodeport() {
    echo -e "${BLUE}🔧 Fix K3s NodePort...${NC}"
    
    # Restart k3s to rebind ports
    echo "Restarting k3s service..."
    sudo systemctl restart k3s
    
    # Wait for k3s to be ready
    echo "Waiting for k3s to be ready..."
    sleep 30
    
    # Verify cluster
    kubectl get nodes
    kubectl get services -n ${NAMESPACE}
    echo "✅ K3s restarted"
}

setup_port_forward() {
    echo -e "${BLUE}🚀 Setup Port Forward alternativo...${NC}"
    
    echo "Creando port-forward per accesso diretto..."
    echo ""
    echo "Frontend port-forward (background):"
    kubectl port-forward -n ${NAMESPACE} --address=0.0.0.0 service/frontend-service 8080:80 &
    FRONTEND_PF_PID=$!
    
    echo "Backend port-forward (background):"
    kubectl port-forward -n ${NAMESPACE} --address=0.0.0.0 service/backend-service 8081:4001 &
    BACKEND_PF_PID=$!
    
    sleep 5
    
    echo -e "${GREEN}✅ Port forwarding attivo:${NC}"
    echo "Frontend: http://${DEV_VM_IP}:8080"
    echo "Backend API: http://${DEV_VM_IP}:8081/api"
    echo ""
    echo "Per terminare port-forward:"
    echo "kill ${FRONTEND_PF_PID} ${BACKEND_PF_PID}"
    
    # Save PIDs for cleanup
    echo "${FRONTEND_PF_PID}" > /tmp/k8s-frontend-pf.pid
    echo "${BACKEND_PF_PID}" > /tmp/k8s-backend-pf.pid
}

check_vmware_networking() {
    echo -e "${BLUE}🖥️ Verifica VMware Networking...${NC}"
    
    echo "Network interfaces:"
    ip addr show | grep -E "(ens|eth|vmnet)" -A 5
    echo ""
    
    echo "Routing table:"
    ip route
    echo ""
    
    echo "VMware network config:"
    ls -la /etc/vmware/ 2>/dev/null || echo "No VMware config found"
}

fix_vmware_networking() {
    echo -e "${BLUE}🔧 Fix VMware Networking...${NC}"
    
    # Restart network services
    echo "Restarting network services..."
    sudo systemctl restart NetworkManager
    sudo systemctl restart systemd-networkd
    
    # Flush and renew network
    echo "Flushing network configuration..."
    sudo ip route flush table main
    sudo systemctl restart networking
    
    echo "✅ Network services restarted"
}

# Main command handling
case "${1:-status}" in
    "status")
        check_vm_connectivity
        echo ""
        check_vm_firewall
        echo ""
        check_k3s_nodeport
        echo ""
        check_vmware_networking
        echo ""
        echo -e "${YELLOW}💡 Se i NodePort non sono reachable da Windows:${NC}"
        echo "1. Prova: $0 fix"
        echo "2. Alternativa: $0 expose (usa port-forward)"
        echo "3. Debug VMware: $0 vmware"
        ;;
    "fix")
        fix_vm_firewall
        echo ""
        fix_k3s_nodeport
        echo ""
        echo -e "${GREEN}✅ Fix completato. Testa l'accesso da Windows.${NC}"
        ;;
    "expose")
        setup_port_forward
        ;;
    "firewall")
        check_vm_firewall
        echo ""
        fix_vm_firewall
        ;;
    "vmware")
        check_vmware_networking
        echo ""
        fix_vmware_networking
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
echo "=== Debug completato ==="
