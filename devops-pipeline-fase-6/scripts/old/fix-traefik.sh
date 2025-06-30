#!/bin/bash

# FASE 6: Fix Traefik Ingress per accesso CRM
# Configura ingress corretto per Traefik k3s

set -euo pipefail

NAMESPACE="crm-system"

echo "=== 🌐 FASE 6: Fix Traefik Ingress CRM ==="
echo "Namespace: ${NAMESPACE}"
echo "Timestamp: $(date)"
echo ""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

fix_traefik_ingress() {
    echo -e "${BLUE}🔧 Fix Traefik Ingress...${NC}"
    
    # Cancella ingress esistente problematico
    echo "Rimozione ingress esistente..."
    kubectl delete ingress crm-ingress -n ${NAMESPACE} 2>/dev/null || echo "Ingress non esistente"
    
    # Crea ingress corretto per Traefik
    echo "Creazione ingress Traefik corretto..."
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crm-ingress
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: "traefik"
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: crm.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 4001
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 4001
EOF
    
    echo -e "${GREEN}✅ Ingress Traefik creato${NC}"
}

create_nodeport_services() {
    echo -e "${BLUE}🔧 Crea servizi NodePort dedicati...${NC}"
    
    # Frontend NodePort diretto
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
  namespace: ${NAMESPACE}
  labels:
    app: frontend
    service-type: nodeport
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
EOF
    
    # Backend NodePort diretto
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport
  namespace: ${NAMESPACE}
  labels:
    app: backend
    service-type: nodeport
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
EOF
    
    echo -e "${GREEN}✅ Servizi NodePort dedicati creati${NC}"
}

verify_access() {
    echo -e "${BLUE}🔍 Verifica accesso...${NC}"
    
    echo "Aspetto 10 secondi per propagazione..."
    sleep 10
    
    # Verifica ingress
    echo "Ingress configurato:"
    kubectl get ingress -n ${NAMESPACE}
    echo ""
    
    # Verifica servizi
    echo "Servizi disponibili:"
    kubectl get services -n ${NAMESPACE}
    echo ""
    
    # Test accesso Traefik
    echo "Test accesso via Traefik (porta 80):"
    if curl -s -o /dev/null -w "%{http_code}" http://192.168.1.29/ | grep -q "200\|404\|302"; then
        echo -e "${GREEN}✅ Frontend Traefik raggiungibile${NC}"
    else
        echo -e "${RED}❌ Frontend Traefik non raggiungibile${NC}"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" http://192.168.1.29/api/health | grep -q "200\|404\|500"; then
        echo -e "${GREEN}✅ Backend Traefik raggiungibile${NC}"
    else
        echo -e "${RED}❌ Backend Traefik non raggiungibile${NC}"
    fi
    
    # Verifica NodePort binding
    echo ""
    echo "Verifica NodePort binding:"
    sudo netstat -tulpn | grep -E ":30002|:30003" || echo "❌ NodePort ancora non in binding"
}

show_access_info() {
    echo ""
    echo -e "${YELLOW}🌐 METODI DI ACCESSO CRM:${NC}"
    echo ""
    echo "📍 METODO 1 - Traefik LoadBalancer (RACCOMANDATO):"
    echo "Frontend: http://192.168.1.29/"
    echo "Backend API: http://192.168.1.29/api"
    echo "Login: admin@crm.local / admin123"
    echo ""
    echo "📍 METODO 2 - NodePort (se funziona):"
    echo "Frontend: http://192.168.1.29:30002"
    echo "Backend API: http://192.168.1.29:30003/api"
    echo ""
    echo "📍 METODO 3 - Con Host Header:"
    echo "curl -H \"Host: crm.local\" http://192.168.1.29/"
    echo ""
    echo "🔍 Per debug:"
    echo "kubectl logs -n kube-system -l app.kubernetes.io/name=traefik"
}

# Main execution
case "${1:-full}" in
    "ingress")
        fix_traefik_ingress
        verify_access
        ;;
    "nodeport")
        create_nodeport_services
        verify_access
        ;;
    "verify")
        verify_access
        ;;
    "full")
        fix_traefik_ingress
        echo ""
        create_nodeport_services
        echo ""
        verify_access
        show_access_info
        ;;
    *)
        echo "Usage: $0 [ingress|nodeport|verify|full]"
        echo ""
        echo "  ingress  - Fix solo Traefik ingress"
        echo "  nodeport - Crea servizi NodePort dedicati"
        echo "  verify   - Verifica accesso"
        echo "  full     - Esegue tutto (default)"
        ;;
esac

echo ""
echo "=== Fix Traefik completato ==="
