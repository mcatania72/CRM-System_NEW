#!/bin/bash

# ================================
# SCRIPT CONFIGURAZIONE FRONTEND NGINX
# Gestisce automaticamente interno K8s vs NodePort esterno
# ================================

set -euo pipefail

NAMESPACE="crm-system"
DEV_VM_IP="192.168.1.29"
BACKEND_NODEPORT="30003"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=== 🔧 CONFIGURAZIONE FRONTEND NGINX ==="

configure_for_nodeport() {
    log_info "🔧 Configurazione nginx per NodePort esterno..."
    
    kubectl patch configmap frontend-nginx-config -n "$NAMESPACE" --patch="
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Handle React Router
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        
        # API proxy to backend NodePort (ESTERNO)
        location /api/ {
            proxy_pass http://${DEV_VM_IP}:${BACKEND_NODEPORT}/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # Health check
        location /health {
            return 200 \"OK\";
            add_header Content-Type text/plain;
        }
        
        # Static assets caching
        location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control \"public, immutable\";
        }
    }
" || { log_error "❌ Patch ConfigMap fallito"; return 1; }
    
    log_success "✅ ConfigMap aggiornato per NodePort"
}

configure_for_internal() {
    log_info "🔧 Configurazione nginx per servizio interno K8s..."
    
    kubectl patch configmap frontend-nginx-config -n "$NAMESPACE" --patch="
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Handle React Router
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        
        # API proxy to backend service (INTERNO K8S)
        location /api/ {
            proxy_pass http://backend-service:4001/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # Health check
        location /health {
            return 200 \"OK\";
            add_header Content-Type text/plain;
        }
        
        # Static assets caching
        location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
            expires 1y;
            add_header Cache-Control \"public, immutable\";
        }
    }
" || { log_error "❌ Patch ConfigMap fallito"; return 1; }
    
    log_success "✅ ConfigMap aggiornato per servizio interno"
}

restart_frontend() {
    log_info "🔄 Restart frontend per applicare configurazione..."
    kubectl rollout restart deployment/frontend -n "$NAMESPACE"
    kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=60s
    log_success "✅ Frontend riavviato"
}

case "${1:-help}" in
    "nodeport")
        configure_for_nodeport
        restart_frontend
        ;;
    "internal")
        configure_for_internal  
        restart_frontend
        ;;
    "help"|*)
        echo "Usage: $0 {nodeport|internal}"
        echo ""
        echo "  nodeport  - Configura nginx per backend NodePort esterno (30003)"
        echo "  internal  - Configura nginx per backend service interno K8s"
        exit 1
        ;;
esac
