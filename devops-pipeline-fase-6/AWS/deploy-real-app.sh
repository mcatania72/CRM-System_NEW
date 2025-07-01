#!/bin/bash

# Deploy Real CRM Application - Usa applicazione esistente

set -euo pipefail

LOG_FILE="$HOME/deploy-real-app.log"
CRM_DIR="$HOME/crm-docker"
SOURCE_DIR="$HOME/CRM-System_NEW"

log() {
    echo "[$(date +'%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 Deploying REAL CRM Application from source..."

# Verifica che la source app esista
if [ ! -d "$SOURCE_DIR" ]; then
    log "❌ ERROR: Source directory $SOURCE_DIR not found!"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/frontend" ]; then
    log "❌ ERROR: Frontend directory $SOURCE_DIR/frontend not found!"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/backend" ]; then
    log "❌ ERROR: Backend directory $SOURCE_DIR/backend not found!"
    exit 1
fi

# Stop container
log "🛑 Stopping containers..."
cd "$CRM_DIR"
docker-compose down

# Backup fake app
log "🗑️ Removing fake applications..."
rm -rf backend frontend

# Copia VERA applicazione
log "📂 Copying REAL frontend application..."
cp -r "$SOURCE_DIR/frontend" "$CRM_DIR/"

log "📂 Copying REAL backend application..."
cp -r "$SOURCE_DIR/backend" "$CRM_DIR/"

# Verifica copia
log "🔍 Verifying copied applications..."
echo "Frontend files:"
ls -la "$CRM_DIR/frontend/" | head -5

echo "Backend files:"
ls -la "$CRM_DIR/backend/" | head -5

# Restart container con vera app
log "🔄 Restarting containers with REAL application..."
docker-compose up -d

# Aspetta startup
log "⏳ Waiting for services to start..."
sleep 30

# Verifica stato
log "📊 Checking service status..."
docker-compose ps

# Test backend con vera app
log "🧪 Testing real backend..."
timeout 10 bash -c 'until curl -s http://localhost:30003/api/health; do sleep 1; done' || log "⚠️ Backend test timeout"

log "✅ REAL CRM application deployed successfully!"

# Show access info
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
echo ""
echo "🌐 ========== ACCESS YOUR REAL CRM =========="
echo "Frontend: http://$PUBLIC_IP:30002"
echo "Backend:  http://$PUBLIC_IP:30003/api"
echo "Login:    admin@crm.local / admin123"
echo "==========================================="
