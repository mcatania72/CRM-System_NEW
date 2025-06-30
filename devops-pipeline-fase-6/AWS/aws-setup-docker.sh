#!/bin/bash

# AWS Setup Script per Docker Compose - EC2 t2.micro
# Setup completo ambiente AWS con ottimizzazioni per risorse limitate

set -euo pipefail

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/aws-setup.log"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# Verifica ambiente AWS EC2
check_aws_environment() {
    log "🔍 Checking AWS EC2 environment..."
    
    # Verifica che siamo su EC2
    if ! curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
        warn "Not running on AWS EC2 or metadata service not available"
    else
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
        
        log "✅ Running on AWS EC2"
        log "   Instance ID: $INSTANCE_ID"
        log "   Instance Type: $INSTANCE_TYPE"
        log "   Availability Zone: $AZ"
        log "   Public IP: $PUBLIC_IP"
        
        if [ "$INSTANCE_TYPE" != "t2.micro" ]; then
            warn "Instance type $INSTANCE_TYPE - these scripts are optimized for t2.micro"
        fi
    fi
}

# Update sistema
update_system() {
    log "📦 Updating system packages..."
    
    sudo apt update
    sudo apt upgrade -y
    
    # Installa pacchetti essenziali
    sudo apt install -y \
        curl \
        wget \
        git \
        htop \
        tree \
        unzip \
        vim \
        jq \
        net-tools \
        dnsutils
    
    log "✅ System updated"
}

# Setup swap per t2.micro
setup_swap() {
    log "💾 Setting up swap for t2.micro..."
    
    # Controlla se swap esiste già
    if swapon --show | grep -q "/swapfile"; then
        log "✅ Swap already configured"
        return
    fi
    
    # Crea swap file 512MB
    sudo fallocate -l 512M /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Rendi permanente
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    
    # Ottimizza swappiness per t2.micro
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
    
    sudo sysctl vm.swappiness=10
    sudo sysctl vm.vfs_cache_pressure=50
    
    log "✅ Swap configured (512MB)"
}

# Installa Docker
install_docker() {
    log "🐳 Installing Docker..."
    
    # Rimuovi versioni vecchie
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Installa Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Aggiungi utente al gruppo docker
    sudo usermod -aG docker ubuntu
    
    # Configura Docker per t2.micro
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    
    # Restart Docker
    sudo systemctl enable docker
    sudo systemctl restart docker
    
    log "✅ Docker installed and configured"
}

# Installa Docker Compose
install_docker_compose() {
    log "🔧 Installing Docker Compose..."
    
    # Scarica ultima versione
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Rendi eseguibile
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Verifica installazione
    docker-compose --version
    
    log "✅ Docker Compose installed: $COMPOSE_VERSION"
}

# Setup Git configuration
setup_git() {
    log "📝 Setting up Git..."
    
    # Configurazione base Git se non presente
    if ! git config --global user.name > /dev/null 2>&1; then
        git config --global user.name "AWS CRM User"
    fi
    
    if ! git config --global user.email > /dev/null 2>&1; then
        git config --global user.email "admin@crm.local"
    fi
    
    # Configurazioni utili
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    
    log "✅ Git configured"
}

# Setup firewall
setup_firewall() {
    log "🛡️ Configuring firewall..."
    
    # Installa ufw se non presente
    sudo apt install -y ufw
    
    # Reset firewall
    sudo ufw --force reset
    
    # Policy di default
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Regole per CRM
    sudo ufw allow 22/tcp         # SSH
    sudo ufw allow 30002/tcp      # Frontend
    sudo ufw allow 30003/tcp      # Backend API
    sudo ufw allow 80/tcp         # HTTP
    sudo ufw allow 443/tcp        # HTTPS
    
    # Abilita firewall
    sudo ufw --force enable
    
    log "✅ Firewall configured"
}

# Ottimizzazioni per t2.micro
optimize_system() {
    log "⚡ Optimizing system for t2.micro..."
    
    # Disabilita servizi non necessari
    sudo systemctl disable snapd 2>/dev/null || true
    sudo systemctl stop snapd 2>/dev/null || true
    
    # Ottimizzazioni kernel
    sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# Ottimizzazioni per t2.micro
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
EOF
    
    # Applica ottimizzazioni
    sudo sysctl -p
    
    # Configura journal per usare meno spazio
    sudo mkdir -p /etc/systemd/journald.conf.d
    sudo tee /etc/systemd/journald.conf.d/99-t2micro.conf > /dev/null << 'EOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=50M
MaxFileSec=1week
MaxRetentionSec=1month
EOF
    
    sudo systemctl restart systemd-journald
    
    log "✅ System optimized for t2.micro"
}

# Setup monitoring
setup_monitoring() {
    log "📊 Setting up basic monitoring..."
    
    # Script di monitoring
    cat > "$HOME/monitor-system.sh" << 'EOF'
#!/bin/bash

echo "=== $(date) ==="
echo "Instance Info:"
curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "Not on EC2"
echo ""

echo "System Resources:"
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h /
echo ""
echo "Load:"
uptime
echo ""

echo "Docker Status:"
if command -v docker &> /dev/null; then
    docker system df
    echo ""
    if docker ps -q > /dev/null 2>&1; then
        echo "Running Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
else
    echo "Docker not installed"
fi
echo ""

echo "Network:"
curl -s http://checkip.amazonaws.com 2>/dev/null && echo " (Public IP)" || echo "Cannot get public IP"
echo ""
EOF
    
    chmod +x "$HOME/monitor-system.sh"
    
    # Cron job per log sistema ogni ora
    (crontab -l 2>/dev/null; echo "0 * * * * $HOME/monitor-system.sh >> $HOME/system-monitor.log 2>&1") | crontab -
    
    log "✅ Basic monitoring setup"
}

# Setup automatico backup
setup_backup() {
    log "💾 Setting up backup system..."
    
    # Script di backup
    cat > "$HOME/backup-crm.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="$HOME/crm-backups"
mkdir -p "$BACKUP_DIR"

if [ -d "$HOME/crm-docker" ]; then
    cd "$HOME/crm-docker"
    
    # Backup database
    if docker-compose ps postgres | grep -q "Up"; then
        BACKUP_FILE="$BACKUP_DIR/crm-db-$(date +%Y%m%d_%H%M%S).sql"
        docker-compose exec -T postgres pg_dump -U crm_user crm_db > "$BACKUP_FILE"
        echo "Database backup saved to $BACKUP_FILE"
        
        # Comprimi backup vecchi di più di 1 giorno
        find "$BACKUP_DIR" -name "*.sql" -mtime +1 -exec gzip {} \;
        
        # Rimuovi backup più vecchi di 7 giorni
        find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
    fi
    
    # Backup configurazioni
    cp docker-compose.yml "$BACKUP_DIR/docker-compose-$(date +%Y%m%d).yml.backup" 2>/dev/null || true
fi
EOF
    
    chmod +x "$HOME/backup-crm.sh"
    
    # Cron job per backup giornaliero alle 2:00 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * $HOME/backup-crm.sh >> $HOME/backup.log 2>&1") | crontab -
    
    log "✅ Backup system configured"
}

# Crea script di gestione
create_management_scripts() {
    log "📝 Creating management scripts..."
    
    # Script di restart rapido
    cat > "$HOME/restart-crm.sh" << 'EOF'
#!/bin/bash
cd "$HOME/crm-docker" || exit 1
echo "Restarting CRM services..."
docker-compose restart
echo "CRM restarted successfully"
EOF
    
    # Script di stop/start
    cat > "$HOME/stop-crm.sh" << 'EOF'
#!/bin/bash
cd "$HOME/crm-docker" || exit 1
echo "Stopping CRM services..."
docker-compose down
echo "CRM stopped"
EOF
    
    cat > "$HOME/start-crm.sh" << 'EOF'
#!/bin/bash
cd "$HOME/crm-docker" || exit 1
echo "Starting CRM services..."
docker-compose up -d
echo "CRM started"
EOF
    
    # Script di status
    cat > "$HOME/status-crm.sh" << 'EOF'
#!/bin/bash
echo "=== CRM Status ==="
if [ -d "$HOME/crm-docker" ]; then
    cd "$HOME/crm-docker"
    docker-compose ps
    echo ""
    echo "URLs:"
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
    echo "Frontend: http://$PUBLIC_IP:30002"
    echo "Backend:  http://$PUBLIC_IP:30003/api"
else
    echo "CRM not deployed yet"
fi
EOF
    
    # Rendi eseguibili
    chmod +x "$HOME"/{restart,stop,start,status}-crm.sh
    
    log "✅ Management scripts created"
}

# Verifica finale
final_verification() {
    log "🔍 Running final verification..."
    
    # Verifica Docker
    if docker --version && docker-compose --version; then
        log "✅ Docker and Docker Compose working"
    else
        error "❌ Docker setup failed"
    fi
    
    # Verifica memoria
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    AVAILABLE_MEM=$(free -m | awk 'NR==2{print $7}')
    SWAP_SIZE=$(free -m | awk 'NR==3{print $2}')
    
    log "Memory: ${TOTAL_MEM}MB total, ${AVAILABLE_MEM}MB available"
    log "Swap: ${SWAP_SIZE}MB configured"
    
    if [ "$AVAILABLE_MEM" -lt 300 ]; then
        warn "Low available memory: ${AVAILABLE_MEM}MB"
    fi
    
    # Verifica spazio disco
    AVAILABLE_DISK=$(df / | awk 'NR==2{print $4}')
    DISK_GB=$((AVAILABLE_DISK / 1024 / 1024))
    
    log "Disk space: ${DISK_GB}GB available"
    
    if [ "$DISK_GB" -lt 10 ]; then
        warn "Low disk space: ${DISK_GB}GB available"
    fi
    
    log "✅ System verification completed"
}

# Mostra riepilogo finale
show_summary() {
    get_public_ip
    
    echo ""
    echo "🎉 ========== AWS EC2 Setup Completed =========="
    echo "✅ Instance optimized for t2.micro"
    echo "✅ Docker and Docker Compose installed"
    echo "✅ Swap configured (512MB)"
    echo "✅ Firewall configured"
    echo "✅ Monitoring and backup setup"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Clone CRM repository or use aws-manager-docker.sh"
    echo "2. Run: ./aws-manager-docker.sh setup"
    echo "3. Access: http://$PUBLIC_IP:30002"
    echo ""
    echo "🛠️ Management Scripts:"
    echo "   ~/restart-crm.sh     - Restart CRM"
    echo "   ~/start-crm.sh       - Start CRM"
    echo "   ~/stop-crm.sh        - Stop CRM"
    echo "   ~/status-crm.sh      - Check status"
    echo "   ~/monitor-system.sh  - System monitor"
    echo "   ~/backup-crm.sh      - Manual backup"
    echo ""
    echo "📊 System Info:"
    echo "   Memory: $(free -h | awk 'NR==2{print $2}') total, $(free -h | awk 'NR==2{print $7}') available"
    echo "   Swap:   $(free -h | awk 'NR==3{print $2}') configured"
    echo "   Disk:   $(df -h / | awk 'NR==2{print $4}') available"
    echo "================================================="
}

# Ottieni IP pubblico
get_public_ip() {
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
}

# Funzione principale
main() {
    case "${1:-setup}" in
        "setup"|"")
            log "🚀 Starting AWS EC2 setup for CRM deployment..."
            check_aws_environment
            update_system
            setup_swap
            install_docker
            install_docker_compose
            setup_git
            setup_firewall
            optimize_system
            setup_monitoring
            setup_backup
            create_management_scripts
            final_verification
            show_summary
            log "✅ AWS EC2 setup completed successfully!"
            ;;
        "verify")
            final_verification
            ;;
        "summary")
            show_summary
            ;;
        *)
            echo "Usage: $0 {setup|verify|summary}"
            echo ""
            echo "setup   - Complete AWS EC2 setup"
            echo "verify  - Verify current setup"
            echo "summary - Show setup summary"
            ;;
    esac
}

# Esegui main
main "$@"
