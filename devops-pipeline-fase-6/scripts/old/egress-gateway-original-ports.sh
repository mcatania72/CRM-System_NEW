#!/bin/bash

# ================================
# EGRESS GATEWAY PORTE ORIGINALI 30002/30003 - FASE 6
# Usa le porte concordate invece di 30080
# ================================

set -euo pipefail

NAMESPACE="crm-system"
FRONTEND_NODEPORT="30002"  # Porta concordata per frontend
BACKEND_NODEPORT="30003"   # Porta concordata per backend
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

echo "=== 🌐 EGRESS GATEWAY - PORTE ORIGINALI 30002/30003 ==="
echo "Frontend NodePort: $FRONTEND_NODEPORT"
echo "Backend NodePort: $BACKEND_NODEPORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: CLEANUP SERVIZI NODEPORT ORIGINALI
# ================================
disable_original_nodeports() {
    log_info "🔄 Disabilita NodePort originali (evita conflitti)..."
    
    # Patch servizi per rimuovere NodePort (diventa ClusterIP)
    kubectl patch service frontend-service -n $NAMESPACE -p '{"spec":{"type":"ClusterIP","ports":[{"port":80,"targetPort":80,"protocol":"TCP"}]}}' 2>/dev/null || true
    kubectl patch service backend-service -n $NAMESPACE -p '{"spec":{"type":"ClusterIP","ports":[{"port":4001,"targetPort":4001,"protocol":"TCP"}]}}' 2>/dev/null || true
    
    log_success "✅ NodePort originali disabilitati"
}

# ================================
# FUNZIONE: CREA CONFIGMAP NGINX DUAL-PORT
# ================================
create_nginx_config_dual() {
    log_info "📋 Creazione configurazione nginx dual-port..."
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: egress-gateway-dual-config
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-dual
    component: proxy
data:
  nginx.conf: |
    # Configurazione Nginx dual-port per 30002/30003
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
        
        # FRONTEND SERVER (porta 8002 interna → NodePort 30002)
        server {
            listen 8002;
            server_name _;
            
            # Security headers
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            
            # Health check
            location /health {
                access_log off;
                return 200 "Frontend Gateway OK\\n";
                add_header Content-Type text/plain;
            }
            
            # Frontend routes (tutto va al frontend)
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
        
        # BACKEND SERVER (porta 8003 interna → NodePort 30003)
        server {
            listen 8003;
            server_name _;
            
            # Security headers
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            
            # Health check
            location /health {
                access_log off;
                return 200 "Backend Gateway OK\\n";
                add_header Content-Type text/plain;
            }
            
            # API routes (tutto va al backend)
            location / {
                proxy_pass http://api-backend/;
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
        }
    }
EOF

    log_success "✅ ConfigMap nginx dual-port creato"
}

# ================================
# FUNZIONE: CREA DEPLOYMENT DUAL-PORT
# ================================
create_gateway_deployment_dual() {
    log_info "🚀 Creazione deployment egress gateway dual-port..."
    
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: egress-gateway-dual
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-dual
    component: proxy
    tier: gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: egress-gateway-dual
      component: proxy
  template:
    metadata:
      labels:
        app: egress-gateway-dual
        component: proxy
        tier: gateway
    spec:
      containers:
      - name: nginx-gateway
        image: nginx:alpine
        ports:
        - containerPort: 8002  # Frontend interno
          name: frontend
          protocol: TCP
        - containerPort: 8003  # Backend interno
          name: backend
          protocol: TCP
        
        # Resource limits
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8002  # Usa frontend per health check
          initialDelaySeconds: 15
          periodSeconds: 20
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8002
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 101  # nginx user
          runAsGroup: 101
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
        
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
          name: egress-gateway-dual-config
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

    log_success "✅ Deployment egress gateway dual-port creato"
}

# ================================
# FUNZIONE: CREA SERVIZI DUAL-PORT
# ================================
create_gateway_services_dual() {
    log_info "🔗 Creazione servizi egress gateway dual-port..."
    
    # Frontend Service (NodePort 30002)
    kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: egress-frontend-service
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-dual
    component: frontend-proxy
spec:
  type: NodePort
  ports:
  - name: frontend
    port: 80
    targetPort: 8002  # Porta interna frontend
    nodePort: $FRONTEND_NODEPORT
    protocol: TCP
  selector:
    app: egress-gateway-dual
    component: proxy
  externalTrafficPolicy: Cluster
EOF

    # Backend Service (NodePort 30003)
    kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: egress-backend-service
  namespace: $NAMESPACE
  labels:
    app: egress-gateway-dual
    component: backend-proxy
spec:
  type: NodePort
  ports:
  - name: backend
    port: 80
    targetPort: 8003  # Porta interna backend
    nodePort: $BACKEND_NODEPORT
    protocol: TCP
  selector:
    app: egress-gateway-dual
    component: proxy
  externalTrafficPolicy: Cluster
EOF

    log_success "✅ Servizi egress gateway dual-port creati"
}

# ================================
# FUNZIONE: VERIFICA DEPLOYMENT
# ================================
verify_gateway_dual() {
    log_info "🔍 Verifica egress gateway dual-port..."
    
    # Wait for deployment
    log_info "⏳ Waiting for deployment ready..."
    kubectl rollout status deployment/egress-gateway-dual -n $NAMESPACE --timeout=60s
    
    # Wait for pods
    log_info "⏳ Waiting for pods ready..."
    kubectl wait --for=condition=ready pod -l app=egress-gateway-dual -n $NAMESPACE --timeout=30s
    
    # Test health interno
    log_info "🧪 Test health gateway..."
    sleep 3
    if kubectl exec -n $NAMESPACE deployment/egress-gateway-dual -- wget -qO- http://localhost:8002/health 2>/dev/null | grep -q "OK"; then
        log_success "✅ Frontend gateway health OK"
    fi
    
    if kubectl exec -n $NAMESPACE deployment/egress-gateway-dual -- wget -qO- http://localhost:8003/health 2>/dev/null | grep -q "OK"; then
        log_success "✅ Backend gateway health OK"
    fi
    
    log_success "✅ Egress Gateway dual-port verificato"
}

# ================================
# FUNZIONE: TEST ACCESSO ESTERNO
# ================================
test_external_access_dual() {
    log_info "🌐 Test accesso esterno porte concordate..."
    
    # Test NodePort Frontend
    log_info "🧪 Test Frontend NodePort $FRONTEND_NODEPORT..."
    if curl -s --connect-timeout 5 "http://localhost:$FRONTEND_NODEPORT/health" > /dev/null; then
        log_success "✅ Frontend NodePort $FRONTEND_NODEPORT OK"
    else
        log_warning "⚠️ Frontend NodePort test da VM non riuscito"
    fi
    
    # Test NodePort Backend
    log_info "🧪 Test Backend NodePort $BACKEND_NODEPORT..."
    if curl -s --connect-timeout 5 "http://localhost:$BACKEND_NODEPORT/health" > /dev/null; then
        log_success "✅ Backend NodePort $BACKEND_NODEPORT OK"
    else
        log_warning "⚠️ Backend NodePort test da VM non riuscito"
    fi
    
    echo ""
    echo "=== 🎯 ACCESS INFORMATION - PORTE CONCORDATE ==="
    echo "🎨 Frontend:     http://$DEV_VM_IP:$FRONTEND_NODEPORT"
    echo "🔌 Backend API:  http://$DEV_VM_IP:$BACKEND_NODEPORT/api"
    echo "🔑 Login:        admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$FRONTEND_NODEPORT"
    echo "curl -I http://$DEV_VM_IP:$BACKEND_NODEPORT/api/health"
    echo ""
    echo "=== 📊 ARCHITETTURA FINALE ==="
    echo "Host Windows → VM:30002 → Egress Gateway → Frontend Pods"
    echo "Host Windows → VM:30003 → Egress Gateway → Backend Pods"
    echo ""
    echo "🎉 PORTE CONCORDATE ATTIVE: 30002 (Frontend) e 30003 (Backend)"
}

# ================================
# FUNZIONE: CLEANUP
# ================================
cleanup_gateway_dual() {
    log_warning "🗑️ Rimozione egress gateway dual-port..."
    
    kubectl delete service egress-frontend-service -n $NAMESPACE 2>/dev/null || true
    kubectl delete service egress-backend-service -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment egress-gateway-dual -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap egress-gateway-dual-config -n $NAMESPACE 2>/dev/null || true
    
    # Cleanup versioni precedenti
    kubectl delete service egress-gateway-service-fixed -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment egress-gateway-fixed -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap egress-gateway-config-fixed -n $NAMESPACE 2>/dev/null || true
    
    log_success "✅ Egress gateway dual-port rimosso"
}

# ================================
# FUNZIONE: STATUS
# ================================
show_status_dual() {
    log_info "📊 Status egress gateway dual-port..."
    
    echo ""
    echo "=== DEPLOYMENT STATUS ==="
    kubectl get deployment egress-gateway-dual -n $NAMESPACE 2>/dev/null || echo "❌ Deployment non trovato"
    
    echo ""
    echo "=== PODS STATUS ==="
    kubectl get pods -l app=egress-gateway-dual -n $NAMESPACE 2>/dev/null || echo "❌ Pod non trovati"
    
    echo ""
    echo "=== SERVICES STATUS ==="
    kubectl get service egress-frontend-service egress-backend-service -n $NAMESPACE 2>/dev/null || echo "❌ Services non trovati"
    
    echo ""
    echo "=== PORTE NODEPORT ==="
    echo "Frontend: $(kubectl get service egress-frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo 'N/A')"
    echo "Backend:  $(kubectl get service egress-backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo 'N/A')"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-deploy}" in
        "deploy"|"create")
            # Cleanup versioni precedenti
            cleanup_gateway_dual
            
            # Disabilita NodePort originali per evitare conflitti
            disable_original_nodeports
            
            # Deploy versione dual-port
            create_nginx_config_dual
            create_gateway_deployment_dual
            create_gateway_services_dual
            verify_gateway_dual
            test_external_access_dual
            ;;
        "verify"|"test")
            verify_gateway_dual
            test_external_access_dual
            ;;
        "status")
            show_status_dual
            ;;
        "cleanup"|"delete")
            cleanup_gateway_dual
            ;;
        "help"|*)
            echo "Usage: $0 {deploy|verify|status|cleanup}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Crea egress gateway porte originali 30002/30003"
            echo "  verify   - Verifica gateway esistente"
            echo "  status   - Mostra status gateway"
            echo "  cleanup  - Rimuove egress gateway"
            echo ""
            echo "Architettura:"
            echo "Host Windows → VM:30002 → Egress Gateway → Frontend"
            echo "Host Windows → VM:30003 → Egress Gateway → Backend"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
