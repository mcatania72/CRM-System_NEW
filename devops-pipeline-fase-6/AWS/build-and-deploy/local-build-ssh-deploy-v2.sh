#!/bin/bash

# =============================================================================
# LOCAL BUILD + SSH DEPLOY SCRIPT - CORRECTED PATH VERSION
# =============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione CORRETTA
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Fix: dalla directory build-and-deploy risaliamo a Claude (4 livelli su)
# build-and-deploy -> AWS -> devops-pipeline-fase-6 -> Claude
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Debug paths
echo -e "${BLUE}[DEBUG]${NC} SCRIPT_DIR: $SCRIPT_DIR"
echo -e "${BLUE}[DEBUG]${NC} PROJECT_ROOT: $PROJECT_ROOT"
echo -e "${BLUE}[DEBUG]${NC} Backend path: $PROJECT_ROOT/backend"
echo -e "${BLUE}[DEBUG]${NC} Frontend path: $PROJECT_ROOT/frontend"
echo ""

# Verifica paths esistenti
if [ ! -d "$PROJECT_ROOT/backend" ]; then
    echo -e "${RED}[ERROR]${NC} Backend directory non trovata: $PROJECT_ROOT/backend"
    echo -e "${YELLOW}[INFO]${NC} Struttura directory PROJECT_ROOT:"
    ls -la "$PROJECT_ROOT/"
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Percorso attuale dello script:"
    echo "   Script: $SCRIPT_DIR"
    echo "   Calcolato PROJECT_ROOT: $PROJECT_ROOT"
    echo "   Dovrebbe essere: /home/devops/Claude"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/frontend" ]; then
    echo -e "${RED}[ERROR]${NC} Frontend directory non trovata: $PROJECT_ROOT/frontend"
    echo -e "${YELLOW}[INFO]${NC} Struttura directory PROJECT_ROOT:"
    ls -la "$PROJECT_ROOT/"
    exit 1
fi

BUILD_DIR="/tmp/crm-build-$(date +%Y%m%d_%H%M%S)"
AWS_USER="ubuntu"
AWS_HOST=""  # Sarà richiesto all'utente
AWS_KEY=""   # Sarà richiesto all'utente
REMOTE_DIR="/home/ubuntu/crm-deploy"

# Funzioni di utility
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# PREREQUISITI E CONFIGURAZIONE
# =============================================================================
check_prerequisites() {
    log_info "Verificando prerequisiti..."
    
    # Check Node.js e npm
    if ! command -v node &> /dev/null; then
        log_error "Node.js non installato!"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm non installato!"
        exit 1
    fi
    
    # Check SSH
    if ! command -v ssh &> /dev/null; then
        log_error "SSH client non installato!"
        exit 1
    fi
    
    # Check SCP
    if ! command -v scp &> /dev/null; then
        log_error "SCP non disponibile!"
        exit 1
    fi
    
    log_success "Prerequisiti OK"
}

get_aws_config() {
    log_info "Configurazione AWS..."
    
    # IP AWS EC2
    if [ -z "$AWS_HOST" ]; then
        read -p "Inserisci IP pubblico AWS EC2: " AWS_HOST
    fi
    
    # AWS keypair
    if [ -z "$AWS_KEY" ]; then
        read -p "Inserisci percorso chiave AWS (.pem): " AWS_KEY
    fi
    
    # Verifica chiave esistente
    if [ ! -f "$AWS_KEY" ]; then
        log_error "File chiave AWS non trovato: $AWS_KEY"
        exit 1
    fi
    
    # Verifica permessi chiave
    chmod 600 "$AWS_KEY"
    
    log_success "Configurazione AWS OK"
    log_info "AWS Host: $AWS_HOST"
    log_info "AWS Key: $AWS_KEY"
}

# =============================================================================
# FASE 1: BUILD LOCALE SU DEV_VM
# =============================================================================
build_backend() {
    log_info "FASE 1.1: Build Backend (TypeScript)..."
    
    cd "$PROJECT_ROOT/backend"
    
    # Verifica package.json
    if [ ! -f "package.json" ]; then
        log_error "Backend package.json non trovato!"
        exit 1
    fi
    
    # Clean install
    log_info "Installing backend dependencies..."
    rm -rf node_modules package-lock.json
    npm install --production=false
    
    # Build TypeScript
    log_info "Building TypeScript backend..."
    npm run build
    
    # Verifica build
    if [ ! -f "dist/app.js" ]; then
        log_error "Build backend fallito - dist/app.js non trovato!"
        exit 1
    fi
    
    log_success "Backend build completato"
}

build_frontend() {
    log_info "FASE 1.2: Build Frontend (React)..."
    
    cd "$PROJECT_ROOT/frontend"
    
    # Verifica package.json
    if [ ! -f "package.json" ]; then
        log_error "Frontend package.json non trovato!"
        exit 1
    fi
    
    # Clean install
    log_info "Installing frontend dependencies..."
    rm -rf node_modules package-lock.json
    npm install --production=false
    
    # Build React
    log_info "Building React frontend..."
    npm run build
    
    # Verifica build
    if [ ! -d "dist" ]; then
        log_error "Build frontend fallito - dist/ non trovato!"
        exit 1
    fi
    
    log_success "Frontend build completato"
}

create_deployment_package() {
    log_info "FASE 1.3: Creazione package deployment..."
    
    # Crea directory temporanea
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Copia backend build
    mkdir -p backend
    cp -r "$PROJECT_ROOT/backend/dist" backend/
    cp "$PROJECT_ROOT/backend/package.json" backend/
    
    # Copia frontend build  
    mkdir -p frontend
    cp -r "$PROJECT_ROOT/frontend/dist" frontend/
    cp "$PROJECT_ROOT/frontend/nginx.conf" frontend/ 2>/dev/null || true
    
    # Crea docker-compose ottimizzato per artifacts
    cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: crm_database
      POSTGRES_USER: crm_user  
      POSTGRES_PASSWORD: crm_password123
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - crm-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U crm_user -d crm_database"]
      interval: 30s
      timeout: 10s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile_inline: |
        FROM node:18-alpine
        WORKDIR /app
        COPY package.json .
        RUN npm install --production --no-audit --no-fund
        COPY dist/ ./dist/
        EXPOSE 4001
        CMD ["node", "dist/app.js"]
    environment:
      NODE_ENV: production
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: crm_database
      DB_USERNAME: crm_user
      DB_PASSWORD: crm_password123
      PORT: 4001
    ports:
      - "30003:4001"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - crm-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:4001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: ./frontend
      dockerfile_inline: |
        FROM nginx:alpine
        COPY dist/ /usr/share/nginx/html/
        COPY nginx.conf /etc/nginx/nginx.conf 2>/dev/null || true
        EXPOSE 80
        CMD ["nginx", "-g", "daemon off;"]
    ports:
      - "30002:80"
    depends_on:
      - backend
    networks:
      - crm-network
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  crm-network:
    driver: bridge
EOF

    # Crea nginx.conf ottimizzato
    cat > frontend/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }
        
        location /api {
            proxy_pass http://backend:4001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

    # Crea script deploy AWS
    cat > deploy-aws.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Deploying CRM on AWS EC2 t2.micro..."

# Stop servizi esistenti
docker-compose down -v 2>/dev/null || true

# Cleanup
docker system prune -f

# Build e deploy
docker-compose up -d --build

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 60

# Test health
echo "🔍 Testing services..."
curl -f http://localhost:30003/api/health || echo "Backend health check failed"
curl -f http://localhost:30002 || echo "Frontend health check failed"

echo "✅ CRM deployment completed!"
echo "📊 Frontend: http://$(curl -s ifconfig.me):30002"
echo "🔧 Backend API: http://$(curl -s ifconfig.me):30003/api"
EOF

    chmod +x deploy-aws.sh
    
    # Crea archivio
    tar -czf crm-deployment.tar.gz .
    
    log_success "Package deployment creato: $BUILD_DIR/crm-deployment.tar.gz"
    log_info "Dimensione: $(du -h crm-deployment.tar.gz | cut -f1)"
}

# =============================================================================
# FASE 2: SSH DEPLOY SU AWS
# =============================================================================
test_ssh_connection() {
    log_info "FASE 2.1: Test connessione SSH..."
    
    ssh -i "$AWS_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "$AWS_USER@$AWS_HOST" "echo 'SSH connection successful'" || {
        log_error "Connessione SSH fallita!"
        exit 1
    }
    
    log_success "Connessione SSH OK"
}

transfer_deployment_package() {
    log_info "FASE 2.2: Transfer deployment package..."
    
    # Upload archivio
    scp -i "$AWS_KEY" -o StrictHostKeyChecking=no \
        "$BUILD_DIR/crm-deployment.tar.gz" \
        "$AWS_USER@$AWS_HOST:/tmp/crm-deployment.tar.gz"
    
    log_success "Package trasferito su AWS"
}

deploy_on_aws() {
    log_info "FASE 2.3: Deploy su AWS EC2..."
    
    ssh -i "$AWS_KEY" -o StrictHostKeyChecking=no "$AWS_USER@$AWS_HOST" << 'EOSSH'
        set -e
        
        echo "🔧 Preparing deployment directory..."
        sudo rm -rf /home/ubuntu/crm-deploy
        mkdir -p /home/ubuntu/crm-deploy
        cd /home/ubuntu/crm-deploy
        
        echo "📦 Extracting deployment package..."
        tar -xzf /tmp/crm-deployment.tar.gz
        
        echo "🚀 Starting CRM deployment..."
        chmod +x deploy-aws.sh
        ./deploy-aws.sh
        
        echo "✅ Deployment completed!"
EOSSH

    log_success "Deploy su AWS completato"
}

# =============================================================================
# FASE 3: TEST E MONITORING
# =============================================================================
test_aws_deployment() {
    log_info "FASE 3.1: Test deployment AWS..."
    
    # Get public IP
    PUBLIC_IP=$(ssh -i "$AWS_KEY" -o StrictHostKeyChecking=no "$AWS_USER@$AWS_HOST" \
        "curl -s ifconfig.me")
    
    log_info "Public IP: $PUBLIC_IP"
    
    # Test endpoints
    log_info "Testing frontend..."
    if curl -s -f "http://$PUBLIC_IP:30002" > /dev/null; then
        log_success "✅ Frontend OK: http://$PUBLIC_IP:30002"
    else
        log_warning "⚠️ Frontend test failed"
    fi
    
    log_info "Testing backend API..."
    if curl -s -f "http://$PUBLIC_IP:30003/api/health" > /dev/null; then
        log_success "✅ Backend API OK: http://$PUBLIC_IP:30003/api"
    else
        log_warning "⚠️ Backend API test failed"
    fi
    
    echo ""
    log_success "🎉 CRM DEPLOYMENT COMPLETED!"
    echo ""
    echo -e "${GREEN}📊 Access URLs:${NC}"
    echo -e "   Frontend: ${BLUE}http://$PUBLIC_IP:30002${NC}"
    echo -e "   Backend API: ${BLUE}http://$PUBLIC_IP:30003/api${NC}"
    echo ""
    echo -e "${GREEN}🔐 Default Login:${NC}"
    echo -e "   Email: admin@crm.local"
    echo -e "   Password: admin123"
    echo ""
}

show_aws_monitoring() {
    log_info "FASE 3.2: AWS Monitoring commands..."
    
    echo ""
    log_info "🔍 Monitoring Commands (run on AWS):"
    echo ""
    echo "# SSH to AWS:"
    echo "ssh -i $AWS_KEY $AWS_USER@$AWS_HOST"
    echo ""
    echo "# Check services:"
    echo "cd /home/ubuntu/crm-deploy && docker-compose ps"
    echo ""
    echo "# View logs:"
    echo "docker-compose logs -f backend"
    echo "docker-compose logs -f frontend"
    echo "docker-compose logs -f postgres"
    echo ""
    echo "# Resource usage:"
    echo "docker stats"
    echo "free -h"
    echo "df -h"
    echo ""
}

cleanup_build() {
    log_info "Cleanup build artifacts..."
    rm -rf "$BUILD_DIR"
    log_success "Cleanup completato"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🚀 CRM LOCAL BUILD + SSH DEPLOY SCRIPT"
    echo ""
    
    # Prerequisites
    check_prerequisites
    get_aws_config
    
    echo ""
    log_info "▶️ FASE 1: BUILD LOCALE (DEV_VM 24GB)"
    build_backend
    build_frontend
    create_deployment_package
    
    echo ""
    log_info "▶️ FASE 2: SSH DEPLOY (AWS t2.micro)"
    test_ssh_connection
    transfer_deployment_package
    deploy_on_aws
    
    echo ""
    log_info "▶️ FASE 3: TEST & MONITORING"
    test_aws_deployment
    show_aws_monitoring
    
    # Cleanup
    cleanup_build
    
    echo ""
    log_success "🎉 ALL PHASES COMPLETED SUCCESSFULLY!"
    echo ""
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
