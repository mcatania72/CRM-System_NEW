#!/bin/bash

# AWS Docker Cleanup - Fix errore rlimit
# Reset completo Docker per risoluzione errore OCI runtime

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

log "🔧 Starting Docker cleanup for rlimit fix..."

# 1. Stop tutto Docker
log "Stopping all Docker containers..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# 2. Stop Docker service
log "Stopping Docker service..."
sudo systemctl stop docker
sudo systemctl stop docker.socket

# 3. Cleanup completo configurazioni
log "Cleaning Docker configurations..."
sudo rm -f /etc/docker/daemon.json
sudo rm -rf /var/lib/docker/containers/*
sudo rm -rf /var/lib/docker/overlay2/*

# 4. Reset configurazione Docker completamente
log "Creating minimal Docker configuration..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "storage-driver": "overlay2"
}
EOF

# 5. Reinstall Docker per sicurezza
log "Reinstalling Docker..."
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
sudo apt autoremove -y
sudo apt update

# Reinstall Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# 6. Aggiungi utente al gruppo
sudo usermod -aG docker ubuntu

# 7. Start Docker
log "Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# 8. Test Docker
log "Testing Docker..."
if docker info > /dev/null 2>&1; then
    log "✅ Docker working correctly"
else
    error "❌ Docker still has issues"
    exit 1
fi

# 9. Test semplice container
log "Testing simple container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log "✅ Container creation working"
else
    error "❌ Container creation still failing"
    exit 1
fi

# 10. Reinstall Docker Compose
log "Reinstalling Docker Compose..."
sudo rm -f /usr/local/bin/docker-compose
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 11. Test Docker Compose
if docker-compose --version > /dev/null 2>&1; then
    log "✅ Docker Compose working"
else
    error "❌ Docker Compose issues"
    exit 1
fi

log "🎉 Docker cleanup completed successfully!"
log "🚀 Ready for CRM deployment"

echo ""
echo "Next steps:"
echo "1. cd ~/CRM-System_NEW/devops-pipeline-fase-6/AWS"
echo "2. ./aws-manager-docker.sh setup"
