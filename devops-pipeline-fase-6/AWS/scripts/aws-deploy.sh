#!/bin/bash

# ================================
# AWS DEPLOY - CRM SYSTEM
# Deploy ottimizzato per EC2 t2.micro (1GB RAM, 1 vCPU)
# ================================

set -euo pipefail

# Configurazione
AWS_REGION="us-east-1"
INSTANCE_NAME="crm-system-instance"
NAMESPACE="crm-system"

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

echo "=== 🚀 AWS DEPLOY - CRM SYSTEM t2.micro ==="
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: CONNETTI A ISTANZA
# ================================
get_instance_info() {
    log_info "🔍 Ricerca istanza AWS..."
    
    # Ottieni informazioni istanza
    local instance_info=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
        --output text 2>/dev/null || echo "None None None")
    
    read -r INSTANCE_ID PUBLIC_IP PRIVATE_IP <<< "$instance_info"
    
    if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ]; then
        log_error "❌ Nessuna istanza CRM trovata in running"
        echo "Crea prima un'istanza con: ./aws-setup.sh create-instance"
        exit 1
    fi
    
    log_success "✅ Istanza trovata: $INSTANCE_ID ($PUBLIC_IP)"
}

# ================================
# FUNZIONE: VERIFICA CONNESSIONE SSH
# ================================
test_ssh_connection() {
    log_info "🔐 Test connessione SSH..."
    
    if [ ! -f "crm-key-pair.pem" ]; then
        log_error "❌ File chiave crm-key-pair.pem non trovato"
        echo "Assicurati di essere nella directory con la chiave SSH"
        exit 1
    fi
    
    # Test connessione SSH
    if ssh -i crm-key-pair.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" 'echo "SSH OK"' &>/dev/null; then
        log_success "✅ Connessione SSH funzionante"
    else
        log_error "❌ Impossibile connettersi via SSH"
        echo "Verifica:"
        echo "1. Istanza completamente avviata"
        echo "2. Security group permette SSH (porta 22)"
        echo "3. File chiave crm-key-pair.pem presente e permessi corretti"
        exit 1
    fi
}

# ================================
# FUNZIONE: VERIFICA PREREQUISITI AWS
# ================================
verify_aws_prerequisites() {
    log_info "🔍 Verifica prerequisiti su istanza AWS..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
set -e

echo "=== Verifica Docker ==="
if ! docker --version; then
    echo "❌ Docker non installato"
    exit 1
fi

echo "=== Verifica k3s ==="
if ! sudo k3s kubectl version; then
    echo "❌ k3s non installato"
    exit 1
fi

echo "=== Verifica setup completo ==="
if [ ! -f /home/ubuntu/setup-complete.txt ]; then
    echo "❌ Setup automatico non completato"
    echo "Attendere il completamento del setup iniziale"
    exit 1
fi

echo "=== Verifica repository ==="
if [ ! -d /home/ubuntu/CRM-System_NEW ]; then
    echo "🔄 Clone repository..."
    git clone https://github.com/mcatania72/CRM-System_NEW.git
fi

echo "✅ Prerequisiti verificati"
EOF

    log_success "✅ Prerequisiti AWS verificati"
}

# ================================
# FUNZIONE: OTTIMIZZA SISTEMA PER t2.micro
# ================================
optimize_system() {
    log_info "⚡ Ottimizzazione sistema per t2.micro..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
set -e

echo "=== Configurazione Swap ==="
# Verifica se swap esiste già
if ! swapon --show | grep -q '/swapfile'; then
    echo "🔄 Creazione swap 1GB..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "=== Tuning kernel per low memory ==="
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "=== Ottimizzazione Docker ==="
sudo tee /etc/docker/daemon.json > /dev/null << 'DOCKER_EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
DOCKER_EOF

sudo systemctl restart docker

echo "=== Configurazione k3s per t2.micro ==="
sudo tee /etc/systemd/system/k3s.service.env > /dev/null << 'K3S_EOF'
K3S_OPTS="--kubelet-arg=eviction-hard=memory.available<100Mi --kubelet-arg=eviction-soft=memory.available<200Mi --kubelet-arg=eviction-soft-grace-period=memory.available=1m30s"
K3S_EOF

sudo systemctl restart k3s
sleep 30

echo "✅ Ottimizzazione completata"
EOF

    log_success "✅ Sistema ottimizzato per t2.micro"
}

# ================================
# FUNZIONE: CREA MANIFESTS OTTIMIZZATI
# ================================
create_optimized_manifests() {
    log_info "📋 Creazione manifests ottimizzati per t2.micro..."
    
    # Crea directory temporanea per manifests
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" 'mkdir -p /tmp/k8s-aws'
    
    # Trasferisci manifests base e li ottimizza
    log_info "📤 Trasferimento e ottimizzazione manifests..."
    
    # Namespace
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/01-namespace.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: crm-system
  labels:
    name: crm-system
    environment: aws-production
MANIFEST_EOF
EOF

    # Secrets
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/02-secrets.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: crm-system
type: Opaque
data:
  POSTGRES_USER: Y3JtX3VzZXI=        # crm_user
  POSTGRES_PASSWORD: Y3JtX3Bhc3N3b3Jk  # crm_password
  POSTGRES_DB: Y3JtX2Ri             # crm_db
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: crm-system
type: Opaque
data:
  JWT_SECRET: bXlfc3VwZXJfc2VjcmV0X2p3dF9rZXlf
  DB_PASSWORD: Y3JtX3Bhc3N3b3Jk
MANIFEST_EOF
EOF

    # PostgreSQL PVC (ridotto per t2.micro)
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/03-postgres-pvc.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: crm-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi  # Ridotto per t2.micro
  storageClassName: local-path
MANIFEST_EOF
EOF

    # PostgreSQL Deployment (ottimizzato per 1GB RAM)
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/04-postgres-deployment.yaml << 'MANIFEST_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: crm-system
  labels:
    app: postgres
    component: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
      component: database
  template:
    metadata:
      labels:
        app: postgres
        component: database
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
        # Ottimizzazioni PostgreSQL per t2.micro
        - name: POSTGRES_SHARED_BUFFERS
          value: "32MB"
        - name: POSTGRES_MAX_CONNECTIONS
          value: "20"
        - name: POSTGRES_WORK_MEM
          value: "1MB"
        - name: POSTGRES_MAINTENANCE_WORK_MEM
          value: "16MB"
        - name: POSTGRES_EFFECTIVE_CACHE_SIZE
          value: "128MB"
        
        resources:
          requests:
            memory: "128Mi"  # 12.5% di 1GB
            cpu: "50m"       # 5% di 1 vCPU
          limits:
            memory: "256Mi"  # 25% di 1GB
            cpu: "200m"      # 20% di 1 vCPU
        
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        
        livenessProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 30
          periodSeconds: 30
        
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - crm_user
            - -d
            - crm_db
          initialDelaySeconds: 10
          periodSeconds: 10
      
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
MANIFEST_EOF
EOF

    # PostgreSQL Service
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/05-postgres-service.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: crm-system
  labels:
    app: postgres
    component: database
spec:
  selector:
    app: postgres
    component: database
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  type: ClusterIP
MANIFEST_EOF
EOF

    # Backend Deployment (ottimizzato)
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/06-backend-deployment.yaml << 'MANIFEST_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: crm-system
  labels:
    app: backend
    component: application
spec:
  replicas: 1  # Solo 1 replica per t2.micro
  selector:
    matchLabels:
      app: backend
      component: application
  template:
    metadata:
      labels:
        app: backend
        component: application
    spec:
      initContainers:
      - name: wait-for-postgres
        image: busybox:1.35
        command: 
        - sh
        - -c
        - |
          echo "Waiting for PostgreSQL to be ready..."
          until nc -z postgres-service 5432; do
            echo "PostgreSQL not ready, waiting..."
            sleep 5
          done
          echo "PostgreSQL is ready!"
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "50m"
      
      containers:
      - name: backend
        image: crm-backend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 4001
          name: http
        
        env:
        - name: NODE_ENV
          value: "production"
        - name: DB_HOST
          value: "postgres-service"
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: JWT_SECRET
        
        # Risorse molto conservative per t2.micro
        resources:
          requests:
            memory: "64Mi"   # 6% di 1GB
            cpu: "25m"       # 2.5% di 1 vCPU
          limits:
            memory: "128Mi"  # 12.5% di 1GB
            cpu: "100m"      # 10% di 1 vCPU
        
        livenessProbe:
          httpGet:
            path: /api/health
            port: 4001
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /api/health
            port: 4001
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
MANIFEST_EOF
EOF

    # Backend Service
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/07-backend-service.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: crm-system
  labels:
    app: backend
    component: application
spec:
  selector:
    app: backend
    component: application
  ports:
  - port: 4001
    targetPort: 4001
    nodePort: 30003
    name: http
  type: NodePort
MANIFEST_EOF
EOF

    # Frontend Deployment (minimal)
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/08-frontend-deployment.yaml << 'MANIFEST_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: crm-system
  labels:
    app: frontend
    component: web
spec:
  replicas: 1  # Solo 1 replica per t2.micro
  selector:
    matchLabels:
      app: frontend
      component: web
  template:
    metadata:
      labels:
        app: frontend
        component: web
    spec:
      containers:
      - name: frontend
        image: crm-frontend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: http
        
        # Risorse minimal per frontend
        resources:
          requests:
            memory: "32Mi"   # 3% di 1GB
            cpu: "10m"       # 1% di 1 vCPU
          limits:
            memory: "64Mi"   # 6% di 1GB
            cpu: "50m"       # 5% di 1 vCPU
        
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
MANIFEST_EOF
EOF

    # Frontend Service
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
cat > /tmp/k8s-aws/09-frontend-service.yaml << 'MANIFEST_EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: crm-system
  labels:
    app: frontend
    component: web
spec:
  selector:
    app: frontend
    component: web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30002
    name: http
  type: NodePort
MANIFEST_EOF
EOF

    log_success "✅ Manifests ottimizzati creati"
}

# ================================
# FUNZIONE: BUILD IMMAGINI DOCKER
# ================================
build_images() {
    log_info "🔨 Build immagini Docker su AWS..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
set -e

cd /home/ubuntu/CRM-System_NEW

echo "=== Build Backend Image ==="
cd backend
docker build -t crm-backend:latest . || {
    echo "❌ Build backend fallito"
    exit 1
}

echo "=== Build Frontend Image ==="
cd ../frontend
docker build -t crm-frontend:latest . || {
    echo "❌ Build frontend fallito"
    exit 1
}

echo "=== Verifica Immagini ==="
docker images | grep crm-

echo "✅ Build immagini completato"
EOF

    log_success "✅ Immagini Docker build completate"
}

# ================================
# FUNZIONE: DEPLOY APPLICAZIONE
# ================================
deploy_application() {
    log_info "🚀 Deploy applicazione CRM su k3s..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
set -e

echo "=== Apply Manifests ==="
cd /tmp/k8s-aws

# Apply in ordine corretto
for manifest in 01-namespace.yaml 02-secrets.yaml 03-postgres-pvc.yaml 05-postgres-service.yaml 04-postgres-deployment.yaml 07-backend-service.yaml 06-backend-deployment.yaml 09-frontend-service.yaml 08-frontend-deployment.yaml; do
    echo "🔄 Applying $manifest..."
    sudo k3s kubectl apply -f "$manifest"
    sleep 5
done

echo "=== Attesa deployment ready ==="
echo "⏳ Waiting for PostgreSQL..."
sudo k3s kubectl rollout status deployment/postgres -n crm-system --timeout=300s

echo "⏳ Waiting for Backend..."
sudo k3s kubectl rollout status deployment/backend -n crm-system --timeout=300s

echo "⏳ Waiting for Frontend..."
sudo k3s kubectl rollout status deployment/frontend -n crm-system --timeout=180s

echo "✅ Deploy completato"
EOF

    log_success "✅ Applicazione deployata su k3s"
}

# ================================
# FUNZIONE: VERIFICA DEPLOYMENT
# ================================
verify_deployment() {
    log_info "🔍 Verifica deployment..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== Status Deployments ==="
sudo k3s kubectl get deployments -n crm-system

echo "=== Status Pods ==="
sudo k3s kubectl get pods -n crm-system

echo "=== Status Services ==="
sudo k3s kubectl get services -n crm-system

echo "=== Resource Usage ==="
sudo k3s kubectl top pods -n crm-system 2>/dev/null || echo "Metrics not available"

echo "=== Test Connectivity ==="
echo "🧪 Test Frontend..."
curl -I http://localhost:30002 || echo "❌ Frontend non raggiungibile"

echo "🧪 Test Backend..."
curl -I http://localhost:30003/api/health || echo "❌ Backend non raggiungibile"
EOF
    
    echo ""
    echo "=== 🎯 ACCESS INFORMATION ==="
    echo "🎨 Frontend:     http://$PUBLIC_IP:30002"
    echo "🔌 Backend API:  http://$PUBLIC_IP:30003/api"
    echo "🔑 Login:        admin@crm.local / admin123"
    echo ""
    echo "=== 🔗 SSH Access ==="
    echo "ssh -i crm-key-pair.pem ubuntu@$PUBLIC_IP"
    
    log_success "✅ Verifica deployment completata"
}

# ================================
# FUNZIONE: SHOW STATUS
# ================================
show_status() {
    log_info "📊 Status deployment AWS..."
    
    get_instance_info
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🖥️ SYSTEM RESOURCES ==="
echo "Memory:"
free -h
echo ""
echo "CPU:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
echo ""
echo "Disk:"
df -h /
echo ""

echo "=== ☸️ KUBERNETES STATUS ==="
sudo k3s kubectl get all -n crm-system

echo "=== 📊 RESOURCE USAGE ==="
sudo k3s kubectl top pods -n crm-system 2>/dev/null || echo "Metrics server not available"
EOF

    echo ""
    echo "=== 🌐 ACCESS URLs ==="
    echo "Frontend: http://$PUBLIC_IP:30002"
    echo "Backend API: http://$PUBLIC_IP:30003/api"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-help}" in
        "install")
            get_instance_info
            test_ssh_connection
            verify_aws_prerequisites
            optimize_system
            create_optimized_manifests
            build_images
            deploy_application
            verify_deployment
            ;;
        "build")
            get_instance_info
            test_ssh_connection
            build_images
            ;;
        "deploy")
            get_instance_info
            test_ssh_connection
            create_optimized_manifests
            deploy_application
            verify_deployment
            ;;
        "status")
            get_instance_info
            show_status
            ;;
        "verify")
            get_instance_info
            test_ssh_connection
            verify_deployment
            ;;
        "help"|*)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  install    - Setup completo: ottimizzazione + build + deploy"
            echo "  build      - Solo build immagini Docker"
            echo "  deploy     - Solo deploy applicazione"
            echo "  status     - Status deployment e risorse"
            echo "  verify     - Verifica deployment esistente"
            echo ""
            echo "Examples:"
            echo "  $0 install     # Setup completo su AWS"
            echo "  $0 status      # Verifica status"
            echo "  $0 verify      # Test deployment"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
