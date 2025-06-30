#!/bin/bash

# FASE 6: Fix Frontend per Port-Forward Backend
# Modifica configurazione frontend per usare port-forward

set -euo pipefail

NAMESPACE="crm-system"

echo "=== 🔧 FASE 6: Fix Frontend Port-Forward Backend ==="
echo "Namespace: ${NAMESPACE}"
echo "Timestamp: $(date)"
echo ""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

get_port_forward_ports() {
    echo -e "${BLUE}🔍 Rileva porte port-forward...${NC}"
    
    # Trova porte port-forward attive
    FRONTEND_PORT=$(ps aux | grep "kubectl port-forward.*frontend" | grep -v grep | sed 's/.*:\([0-9]*\):.*/\1/' | head -1)
    BACKEND_PORT=$(ps aux | grep "kubectl port-forward.*backend" | grep -v grep | sed 's/.*:\([0-9]*\):.*/\1/' | head -1)
    
    if [ -z "$FRONTEND_PORT" ] || [ -z "$BACKEND_PORT" ]; then
        echo -e "${RED}❌ Port-forward non attivo! Eseguire prima:${NC}"
        echo "./scripts/host-vm-network-debug.sh expose"
        return 1
    fi
    
    echo "Frontend port-forward: $FRONTEND_PORT"
    echo "Backend port-forward: $BACKEND_PORT"
    echo ""
}

patch_frontend_config() {
    echo -e "${BLUE}🔧 Patch configurazione frontend...${NC}"
    
    # Backup configurazione attuale
    kubectl get configmap frontend-nginx-config -n ${NAMESPACE} -o yaml > /tmp/frontend-config-backup.yaml
    
    # Crea nuovo nginx.conf per port-forward
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-nginx-config
  namespace: ${NAMESPACE}
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Serve static files
        location / {
            try_files \$uri \$uri/ /index.html;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }
        
        # Proxy API calls to backend port-forward
        location /api/ {
            proxy_pass http://192.168.1.29:${BACKEND_PORT}/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # CORS headers
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            
            # Handle preflight OPTIONS requests
            if (\$request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
                add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain; charset=utf-8';
                add_header 'Content-Length' 0;
                return 204;
            }
        }
        
        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
EOF
    
    echo -e "${GREEN}✅ ConfigMap frontend aggiornato${NC}"
}

restart_frontend_pods() {
    echo -e "${BLUE}🔄 Restart pod frontend...${NC}"
    
    # Restart deployment per caricare nuova configurazione
    kubectl rollout restart deployment/frontend -n ${NAMESPACE}
    
    # Wait for rollout
    echo "Aspetto rollout frontend..."
    kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=120s
    
    echo -e "${GREEN}✅ Frontend riavviato${NC}"
}

test_frontend_backend() {
    echo -e "${BLUE}🧪 Test frontend → backend...${NC}"
    
    echo "Aspetto 10 secondi per stabilizzazione..."
    sleep 10
    
    # Test diretto API tramite frontend
    echo "Test API login tramite frontend:"
    curl -X POST "http://192.168.1.29:${FRONTEND_PORT}/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@crm.local","password":"admin123"}' \
        2>/dev/null | head -c 100 || echo ""
    
    echo ""
    echo -e "${GREEN}✅ Test completato${NC}"
}

show_access_info() {
    echo ""
    echo -e "${YELLOW}🌐 ACCESSO CRM AGGIORNATO:${NC}"
    echo ""
    echo "Frontend: http://192.168.1.29:${FRONTEND_PORT}"
    echo "Backend API: http://192.168.1.29:${BACKEND_PORT}/api"
    echo "Login: admin@crm.local / admin123"
    echo ""
    echo "📱 Il frontend ora chiama il backend via port-forward!"
    echo "🔄 Prova il login nell'interfaccia web"
    echo ""
    echo "Per ripristinare configurazione originale:"
    echo "kubectl apply -f /tmp/frontend-config-backup.yaml"
}

# Main execution
case "${1:-full}" in
    "detect")
        get_port_forward_ports
        ;;
    "patch")
        get_port_forward_ports
        patch_frontend_config
        ;;
    "restart")
        restart_frontend_pods
        ;;
    "test")
        get_port_forward_ports
        test_frontend_backend
        ;;
    "full")
        get_port_forward_ports
        patch_frontend_config
        echo ""
        restart_frontend_pods
        echo ""
        test_frontend_backend
        show_access_info
        ;;
    *)
        echo "Usage: $0 [detect|patch|restart|test|full]"
        echo ""
        echo "  detect  - Rileva porte port-forward"
        echo "  patch   - Aggiorna configurazione frontend"
        echo "  restart - Riavvia pod frontend"
        echo "  test    - Test comunicazione frontend→backend"
        echo "  full    - Esegue tutto (default)"
        ;;
esac

echo ""
echo "=== Fix Frontend Port-Forward completato ==="
