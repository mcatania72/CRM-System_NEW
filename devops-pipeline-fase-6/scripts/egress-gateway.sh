#!/bin/bash

# ================================
# EGRESS GATEWAY per CRM - FASE 6
# Proxy interno Kubernetes per accesso esterno
# ================================

set -euo pipefail

NAMESPACE="crm-system"
GATEWAY_PORT="8080"
DEV_VM_IP="192.168.1.29"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== 🌐 EGRESS GATEWAY CRM - Kubernetes Native ==="
echo "Gateway Port: $GATEWAY_PORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: CREA CONFIGMAP NGINX
# ================================
create_nginx_config() {
    log_info "📋 Creazione configurazione nginx gateway..."
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: egress-gateway-config
  namespace: $NAMESPACE
  labels:
    app: egress-gateway
    component: proxy
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log warn;
    pid /var/run/nginx.pid;
    
    events {
        worker_connections 1024;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        # Logging
        log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                        '\$status \$body_bytes_sent "\$http_referer" '
                        '"\$http_user_agent" "\$http_x_forwarded_for"';
        access_log /var/log/nginx/access.log main;
        
        # Basic settings
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        
        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        
        # Upstream definitions
        upstream frontend-backend {
            server frontend-service:80;
        }
        
        upstream api-backend {
            server backend-service:4001;
        }
        
        # Main server block
        server {
            listen 80;
            server_name _;
            
            # Security headers
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            
            # Health check
            location /health {
                access_log off;
                return 200 "Egress Gateway OK\\n";
                add_header Content-Type text/plain;
            }
            
            # API routes
            location /api/ {
                proxy_pass http://api-backend/api/;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                
                # Timeouts
                proxy_connect_timeout 30s;
                proxy_send_timeout 30s;
                proxy_read_timeout 30s;
                
                # Buffering
                proxy_buffering on;
                proxy_buffer_size 4k;
                proxy_buffers 8 4k;
            }
            
            # Frontend routes (default)
            location / {
                proxy_pass http://frontend-backend/;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                
                # Timeouts
                proxy_connect_timeout 30s;
                proxy_send_timeout 30s;
                proxy_read_timeout 30s;
            }
        }
    }
EOF

    log_success "✅ ConfigMap nginx gateway creato"
}

# ================================
# FUNZIONE: CREA DEPLOYMENT GATEWAY
# ================================
create_gateway_deployment() {
    log_info "🚀 Creazione deployment egress gateway..."
    
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: egress-gateway
  namespace: $NAMESPACE
  labels:
    app: egress-gateway
    component: proxy
    tier: gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: egress-gateway
      component: proxy
  template:
    metadata:
      labels:
        app: egress-gateway
        component: proxy
        tier: gateway
    spec:
      containers:
      - name: nginx-gateway
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        
        # Resource limits
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Startup probe
        startupProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
          failureThreshold: 15
        
        # Volume mounts
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        
        # Security context
        securityContext:
          runAsNonRoot: false
          runAsUser: 0
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
      
      volumes:
      - name: nginx-config
        configMap:
          name: egress-gateway-config
          items:
          - key: nginx.conf
            path: nginx.conf
      
      # Pod anti-affinity per HA
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - egress-gateway
              topologyKey: kubernetes.io/hostname
EOF

    log_success "✅ Deployment egress gateway creato"
}

# ================================
# FUNZIONE: CREA SERVICE GATEWAY
# ================================
create_gateway_service() {
    log_info "🔗 Creazione service egress gateway..."
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: egress-gateway-service
  namespace: $NAMESPACE
  labels:
    app: egress-gateway
    component: proxy
    tier: gateway
  annotations:
    description: "Egress Gateway per accesso esterno CRM"
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: $GATEWAY_PORT  # Porta per accesso esterno
    protocol: TCP
  selector:
    app: egress-gateway
    component: proxy
  
  # Load balancing
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
  
  externalTrafficPolicy: Cluster
EOF

    log_success "✅ Service egress gateway creato"
}

# ================================
# FUNZIONE: VERIFICA DEPLOYMENT
# ================================
verify_gateway() {
    log_info "🔍 Verifica egress gateway..."
    
    # Wait for deployment
    log_info "⏳ Waiting for deployment ready..."
    kubectl rollout status deployment/egress-gateway -n $NAMESPACE --timeout=120s
    
    # Wait for pods
    log_info "⏳ Waiting for pods ready..."
    kubectl wait --for=condition=ready pod -l app=egress-gateway -n $NAMESPACE --timeout=60s
    
    # Check service endpoints
    local endpoints=$(kubectl get endpoints egress-gateway-service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    if [ -n "$endpoints" ]; then
        log_success "✅ Gateway endpoints: $endpoints"
    else
        log_error "❌ Nessun endpoint per gateway"
        return 1
    fi
    
    # Test health interno
    log_info "🧪 Test health gateway..."
    if kubectl exec -n $NAMESPACE deployment/egress-gateway -- curl -s http://localhost/health > /dev/null; then
        log_success "✅ Gateway health OK"
    else
        log_warning "⚠️ Gateway health test failed"
    fi
    
    # Test connettività ai servizi interni
    log_info "🔗 Test connettività interna..."
    if kubectl exec -n $NAMESPACE deployment/egress-gateway -- curl -s http://frontend-service:80 > /dev/null; then
        log_success "✅ Gateway → Frontend OK"
    else
        log_warning "⚠️ Gateway → Frontend FAIL"
    fi
    
    if kubectl exec -n $NAMESPACE deployment/egress-gateway -- curl -s http://backend-service:4001/api/health > /dev/null; then
        log_success "✅ Gateway → Backend OK"
    else
        log_warning "⚠️ Gateway → Backend FAIL"
    fi
    
    log_success "✅ Egress Gateway verificato"
}

# ================================
# FUNZIONE: TEST ACCESSO ESTERNO
# ================================
test_external_access() {
    log_info "🌐 Test accesso esterno..."
    
    # Test locale
    log_info "🧪 Test da DEV_VM..."
    if curl -s --connect-timeout 5 "http://localhost:$GATEWAY_PORT/health" > /dev/null; then
        log_success "✅ Gateway localhost health OK"
    else
        log_error "❌ Gateway localhost health FAIL"
    fi
    
    if curl -s --connect-timeout 5 "http://localhost:$GATEWAY_PORT" > /dev/null; then
        log_success "✅ Gateway localhost frontend OK"
    else
        log_error "❌ Gateway localhost frontend FAIL"
    fi
    
    if curl -s --connect-timeout 5 "http://localhost:$GATEWAY_PORT/api/health" > /dev/null; then
        log_success "✅ Gateway localhost API OK"
    else
        log_error "❌ Gateway localhost API FAIL"
    fi
    
    echo ""
    echo "=== 🎯 ACCESS INFORMATION ==="
    echo "🌐 Egress Gateway URL: http://$DEV_VM_IP:$GATEWAY_PORT"
    echo "🎨 Frontend:           http://$DEV_VM_IP:$GATEWAY_PORT"
    echo "🔌 Backend API:        http://$DEV_VM_IP:$GATEWAY_PORT/api"
    echo "🔑 Login:              admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$GATEWAY_PORT"
    echo "curl -I http://$DEV_VM_IP:$GATEWAY_PORT/api/health"
}

# ================================
# FUNZIONE: CLEANUP
# ================================
cleanup_gateway() {
    log_warning "🗑️ Rimozione egress gateway..."
    
    kubectl delete service egress-gateway-service -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment egress-gateway -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap egress-gateway-config -n $NAMESPACE 2>/dev/null || true
    
    log_success "✅ Egress gateway rimosso"
}

# ================================
# FUNZIONE: STATUS
# ================================
show_status() {
    log_info "📊 Status egress gateway..."
    
    echo ""
    echo "=== DEPLOYMENT STATUS ==="
    kubectl get deployment egress-gateway -n $NAMESPACE 2>/dev/null || echo "❌ Deployment non trovato"
    
    echo ""
    echo "=== PODS STATUS ==="
    kubectl get pods -l app=egress-gateway -n $NAMESPACE 2>/dev/null || echo "❌ Pod non trovati"
    
    echo ""
    echo "=== SERVICE STATUS ==="
    kubectl get service egress-gateway-service -n $NAMESPACE 2>/dev/null || echo "❌ Service non trovato"
    
    echo ""
    echo "=== ENDPOINTS STATUS ==="
    kubectl get endpoints egress-gateway-service -n $NAMESPACE 2>/dev/null || echo "❌ Endpoints non trovati"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-deploy}" in
        "deploy"|"create")
            create_nginx_config
            create_gateway_deployment
            create_gateway_service
            verify_gateway
            test_external_access
            ;;
        "verify"|"test")
            verify_gateway
            test_external_access
            ;;
        "status")
            show_status
            ;;
        "cleanup"|"delete")
            cleanup_gateway
            ;;
        "help"|*)
            echo "Usage: $0 {deploy|verify|status|cleanup}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Crea egress gateway completo (default)"
            echo "  verify   - Verifica gateway esistente"
            echo "  status   - Mostra status gateway"
            echo "  cleanup  - Rimuove egress gateway"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
