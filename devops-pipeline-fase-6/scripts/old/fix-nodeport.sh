#!/bin/bash

# FASE 6: Fix K3s NodePort Binding (VERSIONE SICURA)
# Forza ricreazione servizi NodePort per binding corretto

set -euo pipefail

NAMESPACE="crm-system"

echo "=== 🔧 FASE 6: Fix K3s NodePort Binding (SICURO) ==="
echo "Namespace: ${NAMESPACE}"
echo "Timestamp: $(date)"
echo ""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

backup_and_recreate_services() {
    echo -e "${BLUE}🔄 Backup e ricreazione servizi NodePort...${NC}"
    
    # Backup servizi esistenti
    echo "Backup servizi esistenti..."
    kubectl get service frontend-service -n ${NAMESPACE} -o yaml > /tmp/frontend-service-backup.yaml
    kubectl get service backend-service -n ${NAMESPACE} -o yaml > /tmp/backend-service-backup.yaml
    
    # Cancella servizi esistenti
    echo "Cancellazione servizi esistenti..."
    kubectl delete service frontend-service backend-service -n ${NAMESPACE}
    
    sleep 5
    
    # Ricrea frontend service con configurazione esplicita
    echo "Ricreazione frontend service..."
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: ${NAMESPACE}
  labels:
    app: frontend
    component: web
    tier: frontend
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30002
    protocol: TCP
  selector:
    app: frontend
    component: web
  externalTrafficPolicy: Cluster
EOF
    
    # Ricrea backend service con configurazione esplicita
    echo "Ricreazione backend service..."
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: ${NAMESPACE}
  labels:
    app: backend
    component: application
    tier: backend
spec:
  type: NodePort
  ports:
  - name: http
    port: 4001
    targetPort: 4001
    nodePort: 30003
    protocol: TCP
  selector:
    app: backend
    component: application
  externalTrafficPolicy: Cluster
EOF
    
    echo -e "${GREEN}✅ Servizi ricreati${NC}"
}

verify_nodeport_binding() {
    echo -e "${BLUE}🔍 Verifica binding NodePort...${NC}"
    
    echo "Aspettando che i servizi siano pronti..."
    sleep 10
    
    # Verifica servizi
    echo "Servizi NodePort:"
    kubectl get services -n ${NAMESPACE} -o wide
    echo ""
    
    # Verifica endpoints
    echo "Endpoints:"
    kubectl get endpoints -n ${NAMESPACE}
    echo ""
    
    # Verifica binding porte
    echo "Verifica binding porte NodePort:"
    sudo netstat -tulpn | grep -E ":30002|:30003" || echo "❌ Porte ancora non in binding"
    
    # Test connettività locale
    echo ""
    echo "Test connettività locale:"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:30002/ | grep -q "200\|404\|302"; then
        echo -e "${GREEN}✅ Frontend NodePort 30002 raggiungibile localmente${NC}"
    else
        echo -e "${RED}❌ Frontend NodePort 30002 non raggiungibile${NC}"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:30003/api/health | grep -q "200\|404\|500"; then
        echo -e "${GREEN}✅ Backend NodePort 30003 raggiungibile localmente${NC}"
    else
        echo -e "${RED}❌ Backend NodePort 30003 non raggiungibile${NC}"
    fi
}

fix_k3s_nodeport_config() {
    echo -e "${BLUE}🔧 Fix configurazione K3s NodePort (SICURO)...${NC}"
    
    # Check k3s configuration
    echo "Configurazione K3s attuale:"
    sudo systemctl cat k3s | grep ExecStart || echo "No custom ExecStart"
    
    # Verifica che k3s non abbia --disable-kube-proxy
    if sudo systemctl cat k3s | grep -q "\-\-disable-kube-proxy"; then
        echo -e "${RED}❌ PROBLEMA: k3s ha --disable-kube-proxy${NC}"
        echo "Questo impedisce il funzionamento dei NodePort"
        return 1
    fi
    
    # SICURO: Solo restart k3s senza toccare iptables
    echo "Restart k3s (SICURO - senza modifiche iptables)..."
    sudo systemctl restart k3s
    
    echo "Aspettando k3s restart..."
    sleep 30
    
    # Verifica cluster
    kubectl get nodes
    echo -e "${GREEN}✅ K3s riconfigurato (modo sicuro)${NC}"
}

show_access_info() {
    echo ""
    echo -e "${YELLOW}🌐 INFORMAZIONI ACCESSO:${NC}"
    echo "Frontend CRM: http://192.168.1.29:30002"
    echo "Backend API: http://192.168.1.29:30003/api"
    echo "Credenziali: admin@crm.local / admin123"
    echo ""
    echo "Test da Windows host:"
    echo "curl http://192.168.1.29:30002"
    echo "curl http://192.168.1.29:30003/api/health"
}

# Main execution
case "${1:-services}" in
    "services")
        backup_and_recreate_services
        verify_nodeport_binding
        ;;
    "config")
        fix_k3s_nodeport_config
        ;;
    "verify")
        verify_nodeport_binding
        ;;
    "safe")
        backup_and_recreate_services
        verify_nodeport_binding
        echo ""
        fix_k3s_nodeport_config
        echo ""
        verify_nodeport_binding
        show_access_info
        ;;
    *)
        echo "Usage: $0 [services|config|verify|safe]"
        echo ""
        echo "  services - Ricrea solo i servizi NodePort"
        echo "  config   - Restart k3s (SICURO)"
        echo "  verify   - Verifica binding e connettività"
        echo "  safe     - Esegue tutto in modo SICURO (default)"
        ;;
esac

echo ""
echo "=== Fix NodePort completato (versione sicura) ==="
