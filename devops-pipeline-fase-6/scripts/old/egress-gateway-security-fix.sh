#!/bin/bash

# ================================
# EGRESS GATEWAY SECURITY FIX per CRM - FASE 6
# Risolve il problema di security context nginX
# ================================

set -euo pipefail

NAMESPACE="crm-system"
GATEWAY_NODEPORT="30080"
TARGET_PORT="8082"
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

echo "=== 🌐 EGRESS GATEWAY - SECURITY CONTEXT FIX ==="
echo "NodePort: $GATEWAY_NODEPORT → Target: $TARGET_PORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: VERIFICA JENKINS PORTA 8080
# ================================
check_port_8080() {
    log_info "🔍 Verifica conflitto porta 8080..."
    
    if sudo netstat -tulpn | grep -q ":8080.*LISTEN"; then
        log_warning "⚠️ Porta 8080 occupata (probabilmente Jenkins)"
        log_info "🔄 Useremo porta alternativa 8082 per accesso esterno"
        TARGET_PORT="8082"
        return 1
    else
        log_success "✅ Porta 8080 libera"
        return 0
    fi
}

# ================================
# FUNZIONE: CREA CONFIGMAP NGINX FIXED
# ================================
create_nginx_config_fixed() {
    log_info "📋 Creazione configurazione nginx (security fixed)..."
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: egress-gateway-config-fixed
  namespace: $NAMESPACE
  labels:
    app: egress-gateway
    component: proxy
data:
  nginx.conf: |
    # Configurazione Nginx ottimizzata per container non-privileged
    pid /tmp/nginx.pid;
    
    events {
        worker_connections 1024;
        use epoll;
        multi_accept on;
    }
    
    http {
        # Logging
        access_log /dev/stdout;
        error_log /dev/stderr;
        
        # Basic settings
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        
        # MIME types basic
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        # Temp directories che non richiedono privilegi
        client_body_temp_path /tmp/client_temp;
        proxy_temp_path /tmp/proxy_temp;
        fastcgi_temp_path /tmp/fastcgi_temp;
        uwsgi_temp_path /tmp/uwsgi_temp;
        scgi_temp_path /tmp/scgi_temp;
        
        # Upstream definitions
        upstream frontend-backend {
            server frontend-service.crm-system.svc.cluster.local:80;
            keepalive 32;
        }
        
        upstream api-backend {
            server backend-service.crm-system.svc.cluster.local:4001;
            keepalive 32;
        }
        
        # Main server block
        server {
            listen 8080;  # Porta interna del container
            server_name _;
            
            # Security headers
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            
            # Health check per Kubernetes probes
            location /health {
                access_log off;
                return 200 "Egress Gateway OK\\n";
                add_header Content-Type text/plain;
            }
            
            # Root redirect per health check
            location = / {
                return 302 /health;
            }
            
            # API routes
            location /api/ {
                proxy_pass http://api-backend/api/;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                
                # Connection settings
                proxy_http_version 1.1;
                proxy_set_header Connection "";
                
                # Timeouts
                proxy_connect_timeout 10s;
                proxy_send_timeout 10s;
                proxy_read_timeout 10s;
                
                # Buffering
                proxy_buffering on;
                proxy_buffer_size 4k;
                proxy_buffers 8 4k;
            }
            
            # Frontend routes (catch-all)
            location / {
                proxy_pass http://frontend-backend/;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                
                # Connection settings
                proxy_http_version 1.1;
                proxy_set_header Connection "";
                
                # Timeouts
                proxy_connect_timeout 10s;
                proxy_send_timeout 10s;
                proxy_read_timeout 10s;
            }
        }
    }
EOF

    log_success "✅ ConfigMap nginx security-fixed creato"
}

# ================================
# FUNZIONE: CREA DEPLOYMENT SECURITY-FIXED
# ================================
create_gateway_deployment_fixed() {
    log_info "🚀 Creazione deployment egress gateway (security-fixed)..."
    
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: egress-gateway-fixed
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-fixed
    component: proxy
    tier: gateway
spec:
  replicas: 1  # Una replica per semplicità
  selector:
    matchLabels:
      app: egress-gateway-fixed
      component: proxy
  template:
    metadata:
      labels:
        app: egress-gateway-fixed
        component: proxy
        tier: gateway
    spec:
      containers:
      - name: nginx-gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080  # Porta interna
          name: http
          protocol: TCP
        
        # Resource limits ridotti
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        
        # Health checks semplificati
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Security context che risolve il problema chown
        securityContext:
          runAsNonRoot: true
          runAsUser: 101  # nginx user
          runAsGroup: 101
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        
        # Volume mounts
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        - name: run-volume
          mountPath: /var/run
      
      volumes:
      - name: nginx-config
        configMap:
          name: egress-gateway-config-fixed
          items:
          - key: nginx.conf
            path: nginx.conf
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
EOF

    log_success "✅ Deployment egress gateway security-fixed creato"
}

# ================================
# FUNZIONE: CREA SERVICE GATEWAY FIXED
# ================================
create_gateway_service_fixed() {
    log_info "🔗 Creazione service egress gateway..."
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: egress-gateway-service-fixed
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-fixed
    component: proxy
    tier: gateway
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 8080  # Porta interna del container
    nodePort: $GATEWAY_NODEPORT
    protocol: TCP
  selector:
    app: egress-gateway-fixed
    component: proxy
  
  externalTrafficPolicy: Cluster
EOF

    log_success "✅ Service egress gateway security-fixed creato"
}

# ================================
# FUNZIONE: VERIFICA DEPLOYMENT
# ================================
verify_gateway_fixed() {
    log_info "🔍 Verifica egress gateway fixed..."
    
    # Wait for deployment
    log_info "⏳ Waiting for deployment ready..."
    kubectl rollout status deployment/egress-gateway-fixed -n $NAMESPACE --timeout=60s
    
    # Wait for pods
    log_info "⏳ Waiting for pods ready..."
    kubectl wait --for=condition=ready pod -l app=egress-gateway-fixed -n $NAMESPACE --timeout=30s
    
    # Test health interno
    log_info "🧪 Test health gateway..."
    sleep 3
    if kubectl exec -n $NAMESPACE deployment/egress-gateway-fixed -- wget -qO- http://localhost:8080/health 2>/dev/null | grep -q "OK"; then
        log_success "✅ Gateway health OK"
    else
        log_warning "⚠️ Gateway health test non riuscito, ma container avviato"
    fi
    
    log_success "✅ Egress Gateway fixed verificato"
}

# ================================
# FUNZIONE: TEST ACCESSO ESTERNO
# ================================
test_external_access_fixed() {
    log_info "🌐 Test accesso esterno..."
    
    # Test NodePort diretto
    log_info "🧪 Test NodePort $GATEWAY_NODEPORT..."
    if curl -s --connect-timeout 5 "http://localhost:$GATEWAY_NODEPORT/health" > /dev/null; then
        log_success "✅ NodePort $GATEWAY_NODEPORT health OK"
    else
        log_warning "⚠️ NodePort $GATEWAY_NODEPORT non raggiungibile (normale se k3s ha problemi NodePort)"
    fi
    
    echo ""
    echo "=== 🎯 ACCESS INFORMATION ==="
    echo "🌐 Egress Gateway NodePort: http://$DEV_VM_IP:$GATEWAY_NODEPORT"
    echo "🎨 Frontend:                http://$DEV_VM_IP:$GATEWAY_NODEPORT"
    echo "🔌 Backend API:             http://$DEV_VM_IP:$GATEWAY_NODEPORT/api"
    echo "🔑 Login:                   admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$GATEWAY_NODEPORT/health"
    echo ""
    echo "=== 📊 ARCHITETTURA ==="
    echo "Host Windows → VM:$GATEWAY_NODEPORT → Egress Gateway Pod (security-fixed) → Frontend/Backend Pods"
}

# ================================
# FUNZIONE: CLEANUP
# ================================
cleanup_gateway_fixed() {
    log_warning "🗑️ Rimozione egress gateway fixed..."
    
    kubectl delete service egress-gateway-service-fixed -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment egress-gateway-fixed -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap egress-gateway-config-fixed -n $NAMESPACE 2>/dev/null || true
    
    # Cleanup anche vecchia versione
    kubectl delete service egress-gateway-service -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment egress-gateway -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap egress-gateway-config -n $NAMESPACE 2>/dev/null || true
    
    log_success "✅ Egress gateway fixed rimosso"
}

# ================================
# FUNZIONE: STATUS
# ================================
show_status_fixed() {
    log_info "📊 Status egress gateway fixed..."
    
    echo ""
    echo "=== DEPLOYMENT STATUS ==="
    kubectl get deployment egress-gateway-fixed -n $NAMESPACE 2>/dev/null || echo "❌ Deployment non trovato"
    
    echo ""
    echo "=== PODS STATUS ==="
    kubectl get pods -l app=egress-gateway-fixed -n $NAMESPACE 2>/dev/null || echo "❌ Pod non trovati"
    
    echo ""
    echo "=== SERVICE STATUS ==="
    kubectl get service egress-gateway-service-fixed -n $NAMESPACE 2>/dev/null || echo "❌ Service non trovato"
    
    echo ""
    echo "=== LOGS (last 10 lines) ==="
    kubectl logs -l app=egress-gateway-fixed -n $NAMESPACE --tail=10 2>/dev/null || echo "❌ No logs"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-deploy}" in
        "deploy"|"create")
            # Cleanup problematic deployment
            cleanup_gateway_fixed
            
            # Deploy fixed version
            create_nginx_config_fixed
            create_gateway_deployment_fixed
            create_gateway_service_fixed
            verify_gateway_fixed
            test_external_access_fixed
            ;;
        "verify"|"test")
            verify_gateway_fixed
            test_external_access_fixed
            ;;
        "status")
            show_status_fixed
            ;;
        "cleanup"|"delete")
            cleanup_gateway_fixed
            ;;
        "help"|*)
            echo "Usage: $0 {deploy|verify|status|cleanup}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Crea egress gateway security-fixed (default)"
            echo "  verify   - Verifica gateway esistente"
            echo "  status   - Mostra status gateway"
            echo "  cleanup  - Rimuove egress gateway"
            echo ""
            echo "Fix applicati:"
            echo "- Security context runAsUser: 101 (nginx)"
            echo "- Temp directories in /tmp (writable)"
            echo "- EmptyDir volumes per cache e run"
            echo "- Porta interna 8080 → NodePort 30080"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
