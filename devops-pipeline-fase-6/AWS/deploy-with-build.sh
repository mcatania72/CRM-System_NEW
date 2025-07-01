#!/bin/bash

# Deploy Real CRM with Build - Backend TypeScript + Frontend React

set -euo pipefail

LOG_FILE="$HOME/deploy-with-build.log"
CRM_DIR="$HOME/crm-docker"
SOURCE_DIR="$HOME/CRM-System_NEW"

log() {
    echo "[$(date +'%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 Deploying REAL CRM with TypeScript build..."

# Installa Node.js e npm se non presenti
log "💻 Installing Node.js and npm..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Verifica installazione
node --version
npm --version

log "✅ Node.js and npm ready"

# Stop container
log "🛑 Stopping containers..."
cd "$CRM_DIR"
docker-compose down

# Backup current e pulisci
log "🗑️ Cleaning old applications..."
docker run --rm -v $(pwd):/data alpine:latest sh -c "rm -rf /data/backend /data/frontend"

# Copia sorgenti
log "📂 Copying source applications..."
cp -r "$SOURCE_DIR/frontend" "$CRM_DIR/"
cp -r "$SOURCE_DIR/backend" "$CRM_DIR/"

# BUILD BACKEND TypeScript in Docker container
log "🔨 Building backend TypeScript in Docker..."
cd "$CRM_DIR/backend"

# Build usando container Docker con più memoria
docker run --rm \
    -v $(pwd):/app \
    -w /app \
    --memory=800m \
    node:18-alpine sh -c "
        npm install --production=false
        npm run build
    "

# Verifica build
if [ ! -f "dist/app.js" ]; then
    log "❌ Backend build failed - dist/app.js not found"
    exit 1
fi

log "✅ Backend built successfully in Docker"

# BUILD FRONTEND React in Docker container
log "🔨 Building frontend React in Docker..."
cd "$CRM_DIR/frontend"

# Build usando container Docker con più memoria
docker run --rm \
    -v $(pwd):/app \
    -w /app \
    --memory=800m \
    node:18-alpine sh -c "
        npm install --production=false
        npm run build
    "

# Verifica build
if [ ! -d "dist" ]; then
    log "❌ Frontend build failed - dist directory not found"
    exit 1
fi

log "✅ Frontend built successfully in Docker"

# Crea nuovo docker-compose.yml per app compilate
log "📝 Creating docker-compose.yml for built applications..."
cd "$CRM_DIR"

cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: crm-postgres
    environment:
      POSTGRES_DB: crm_db
      POSTGRES_USER: crm_user
      POSTGRES_PASSWORD: crm_password123
      POSTGRES_INITDB_ARGS: "--data-checksums"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    command: >
      postgres
      -c shared_buffers=64MB
      -c max_connections=100
      -c work_mem=4MB
      -c maintenance_work_mem=64MB
      -c wal_buffers=2MB
      -c log_statement=none
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U crm_user -d crm_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: node:18-alpine
    container_name: crm-backend
    working_dir: /app
    environment:
      NODE_ENV: production
      DB_TYPE: postgres
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USERNAME: crm_user
      DB_PASSWORD: crm_password123
      DB_DATABASE: crm_db
      JWT_SECRET: crm-super-secret-jwt-key-2024
      PORT: 4001
      TYPEORM_SYNCHRONIZE: "true"
      TYPEORM_LOGGING: "false"
    volumes:
      - ./backend:/app
    ports:
      - "30003:4001"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    command: ["node", "dist/app.js"]
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: nginx:alpine
    container_name: crm-frontend
    volumes:
      - ./frontend/dist:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "30002:80"
    depends_on:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
    driver: local

networks:
  default:
    driver: bridge
EOF

# Crea init-db.sql per TypeORM
log "🗄️ Creating database initialization..."
cat > init-db.sql << 'EOF'
-- CRM Database for TypeORM
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Database will be initialized by TypeORM synchronize
-- This just ensures extensions are available

COMMIT;
EOF

# Restart con app compilata
log "🔄 Starting compiled applications..."
docker-compose up -d

# Aspetta startup
log "⏳ Waiting for services to initialize..."
sleep 45

# Verifica stato
log "📊 Checking service status..."
docker-compose ps

# Test backend
log "🧪 Testing backend..."
timeout 15 bash -c 'until curl -s http://localhost:30003/api/health; do sleep 2; done' && log "✅ Backend healthy" || log "⚠️ Backend not responding"

log "🎉 REAL CRM deployed with builds!"

# Access info
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
echo ""
echo "🌐 ========== REAL CRM ACCESS =========="
echo "Frontend: http://$PUBLIC_IP:30002"
echo "Backend:  http://$PUBLIC_IP:30003/api"
echo ""
echo "🔐 Login Credentials:"
echo "Email: admin@crm.local"
echo "Password: admin123"
echo ""
echo "📋 Features:"
echo "- Dashboard with analytics"
echo "- Customer management"
echo "- Opportunities tracking"
echo "- Activities logging"
echo "- Interactions history"
echo "======================================"
