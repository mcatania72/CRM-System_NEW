#!/bin/bash

# ================================
# EGRESS GATEWAY FIXED per CRM - FASE 6
# Proxy interno Kubernetes con NodePort valido + Port Forward
# ================================

set -euo pipefail

NAMESPACE="crm-system"
GATEWAY_NODEPORT="30080"  # NodePort valido nel range 30000-32767
TARGET_PORT="8080"        # Porta finale desiderata per accesso esterno
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

echo "=== 🌐 EGRESS GATEWAY CRM - Kubernetes Native (FIXED) ==="
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
# FUNZIONE: TROVA PORTA LIBERA
# ================================
find_free_port() {
    local start_port=${1:-8082}
    local port=$start_port
    
    while sudo netstat -tulpn | grep -q ":$port.*LISTEN"; do
        ((port++))
        if [ $port -gt 8090 ]; then
            log_error "❌ Nessuna porta libera trovata nel range 8082-8090"
            exit 1
        fi
    done
    
    echo $port
}

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
    nodePort: $GATEWAY_NODEPORT  # NodePort valido: 30080
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
# FUNZIONE: SETUP PORT FORWARD ESTERNO
# ================================
setup_port_forward() {
    local gateway_port=$TARGET_PORT
    
    log_info "🔄 Setup port forward: $gateway_port → $GATEWAY_NODEPORT..."
    
    # Kill existing port-forward per questa porta
    sudo pkill -f "port-forward.*$gateway_port" 2>/dev/null || true
    
    # Attendi un po' per cleanup
    sleep 2
    
    # Crea nuovo port-forward in background
    nohup kubectl port-forward --address=0.0.0.0 service/egress-gateway-service $gateway_port:80 -n $NAMESPACE > /tmp/egress-gateway-pf.log 2>&1 &
    local pf_pid=$!
    
    # Salva PID per cleanup futuro
    echo $pf_pid > /tmp/egress-gateway-pf.pid
    
    # Attendi che il port-forward sia attivo
    sleep 3
    
    # Verifica che sia attivo
    if kill -0 $pf_pid 2>/dev/null; then
        log_success "✅ Port-forward attivo (PID: $pf_pid)"
        
        # Apri porta nel firewall se necessario
        if ! sudo ufw status | grep -q "$gateway_port/tcp.*ALLOW"; then
            log_info "🔥 Apertura porta $gateway_port nel firewall..."
            sudo ufw allow $gateway_port/tcp comment "Egress Gateway" >/dev/null 2>&1
            log_success "✅ Firewall aggiornato per porta $gateway_port"
        fi
        
        return 0
    else
        log_error "❌ Port-forward fallito"
        return 1
    fi
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
    
    # Test NodePort diretto
    log_info "🧪 Test NodePort $GATEWAY_NODEPORT..."
    if curl -s --connect-timeout 5 "http://localhost:$GATEWAY_NODEPORT/health" > /dev/null; then
        log_success "✅ NodePort $GATEWAY_NODEPORT health OK"
    else
        log_warning "⚠️ NodePort $GATEWAY_NODEPORT health FAIL"
    fi
    
    # Test port-forward
    if [ -f /tmp/egress-gateway-pf.pid ]; then
        local pf_pid=$(cat /tmp/egress-gateway-pf.pid)
        if kill -0 $pf_pid 2>/dev/null; then
            log_info "🧪 Test port-forward $TARGET_PORT..."
            if curl -s --connect-timeout 5 "http://localhost:$TARGET_PORT/health" > /dev/null; then
                log_success "✅ Port-forward $TARGET_PORT health OK"
            else
                log_warning "⚠️ Port-forward $TARGET_PORT health FAIL"
            fi
        fi
    fi
    
    echo ""
    echo "=== 🎯 ACCESS INFORMATION ==="
    echo "🌐 Egress Gateway NodePort: http://$DEV_VM_IP:$GATEWAY_NODEPORT"
    echo "🌐 Egress Gateway Proxied:  http://$DEV_VM_IP:$TARGET_PORT"
    echo "🎨 Frontend:                http://$DEV_VM_IP:$TARGET_PORT"
    echo "🔌 Backend API:             http://$DEV_VM_IP:$TARGET_PORT/api"
    echo "🔑 Login:                   admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$TARGET_PORT"
    echo "curl -I http://$DEV_VM_IP:$TARGET_PORT/api/health"
    echo ""
    echo "=== 📊 ARCHITETTURA ==="
    echo "Host Windows → VM:$TARGET_PORT → NodePort:$GATEWAY_NODEPORT → Egress Gateway Pod → Frontend/Backend Pods"
}

# ================================
# FUNZIONE: CLEANUP
# ================================
cleanup_gateway() {
    log_warning "🗑️ Rimozione egress gateway..."
    
    # Stop port-forward
    if [ -f /tmp/egress-gateway-pf.pid ]; then
        local pf_pid=$(cat /tmp/egress-gateway-pf.pid)
        if kill -0 $pf_pid 2>/dev/null; then
            log_info "🔄 Stop port-forward (PID: $pf_pid)..."
            kill $pf_pid
        fi
        rm -f /tmp/egress-gateway-pf.pid
    fi
    
    # Cleanup any port-forward process
    sudo pkill -f "port-forward.*egress-gateway" 2>/dev/null || true
    
    # Remove firewall rule if exists
    if sudo ufw status | grep -q "$TARGET_PORT/tcp.*ALLOW"; then
        log_info "🔥 Rimozione regola firewall $TARGET_PORT..."
        sudo ufw delete allow $TARGET_PORT/tcp >/dev/null 2>&1
    fi
    
    # Remove k8s resources
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
    echo "=== PORT-FORWARD STATUS ==="
    if [ -f /tmp/egress-gateway-pf.pid ]; then
        local pf_pid=$(cat /tmp/egress-gateway-pf.pid)
        if kill -0 $pf_pid 2>/dev/null; then
            echo "✅ Port-forward attivo (PID: $pf_pid)"
            echo "📍 Port mapping: $TARGET_PORT → $GATEWAY_NODEPORT"
        else
            echo "❌ Port-forward non attivo"
        fi
    else
        echo "❌ Nessun port-forward configurato"
    fi
    
    echo ""
    echo "=== NETWORK STATUS ==="
    echo "🔍 Porte in ascolto:"
    sudo netstat -tulpn | grep -E ":$GATEWAY_NODEPORT|:$TARGET_PORT" | head -5
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-deploy}" in
        "deploy"|"create")
            # Check for conflicts
            check_port_8080 || TARGET_PORT=$(find_free_port)
            
            # Deploy gateway
            create_nginx_config
            create_gateway_deployment
            create_gateway_service
            verify_gateway
            
            # Setup external access
            setup_port_forward
            
            # Final test
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
            echo ""
            echo "Architettura:"
            echo "Host Windows → VM:8082 → NodePort:30080 → Egress Gateway Pod → Frontend/Backend"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
