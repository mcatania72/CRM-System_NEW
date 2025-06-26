#!/bin/bash

# Prerequisites Docker Script - FASE 2
# Verifica Docker, Docker Compose e altri prerequisiti per containerizzazione

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="$HOME/prerequisites-docker.log"

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

echo ""
echo "======================================="
echo "   CRM System - Prerequisites Docker"
echo "   FASE 2: Containerizzazione Completa"
echo "======================================="

log_info "Verifica prerequisiti Docker per FASE 2..."

# Array per tracciare i prerequisiti mancanti
MISSING_DEPS=()

# Funzione per verificare comandi
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    log_info "Verifico $name..."
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        case $cmd in
            "docker")
                version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
                ;;
            "docker-compose")
                version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
                ;;
            *)
                version=$("$cmd" --version 2>/dev/null | head -1 || echo "installato")
                ;;
        esac
        log_success "$name trovato: $version"
        return 0
    else
        log_error "$name non trovato"
        MISSING_DEPS+=("$name: $install_hint")
        return 1
    fi
}

# Verifica prerequisiti base (dalla FASE 1)
log_info "=== Prerequisiti Base (FASE 1) ==="
check_command "node" "Node.js" "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
check_command "npm" "npm" "Installato con Node.js"
check_command "git" "Git" "sudo apt-get install -y git"
check_command "curl" "curl" "sudo apt-get install -y curl"
check_command "sqlite3" "SQLite3" "sudo apt-get install -y sqlite3"

# Verifica prerequisiti Docker (FASE 2)
log_info "=== Prerequisiti Docker (FASE 2) ==="
check_command "docker" "Docker" "curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker \$USER"
check_command "docker-compose" "Docker Compose" "sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"

# Verifica servizio Docker
log_info "Verifico servizio Docker..."
if systemctl is-active --quiet docker; then
    log_success "Servizio Docker attivo"
else
    log_warning "Servizio Docker non attivo, provo ad avviarlo..."
    if sudo systemctl start docker; then
        log_success "Servizio Docker avviato"
    else
        log_error "Impossibile avviare servizio Docker"
        MISSING_DEPS+=("Docker Service: sudo systemctl start docker")
    fi
fi

# Verifica permessi Docker
log_info "Verifico permessi Docker..."
if docker ps >/dev/null 2>&1; then
    log_success "Permessi Docker OK"
else
    log_warning "Permessi Docker insufficienti"
    log_info "Provo ad aggiungere utente al gruppo docker..."
    sudo usermod -aG docker "$USER"
    log_warning "RIAVVIO NECESSARIO: Effettua logout/login o riavvia per applicare i permessi Docker"
    log_warning "Oppure usa: newgrp docker"
fi

# Verifica versioni minime
log_info "=== Verifica Versioni Minime ==="

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ "$(printf '%s\n' "20.10" "$DOCKER_VERSION" | sort -V | head -n1)" = "20.10" ]; then
        log_success "Docker versione OK: $DOCKER_VERSION (>= 20.10)"
    else
        log_warning "Docker versione troppo vecchia: $DOCKER_VERSION (raccomandato >= 20.10)"
    fi
fi

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ "$(printf '%s\n' "1.29" "$COMPOSE_VERSION" | sort -V | head -n1)" = "1.29" ]; then
        log_success "Docker Compose versione OK: $COMPOSE_VERSION (>= 1.29)"
    else
        log_warning "Docker Compose versione troppo vecchia: $COMPOSE_VERSION (raccomandato >= 1.29)"
    fi
fi

# Verifica spazio disco
log_info "=== Verifica Risorse Sistema ==="
DISK_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_SPACE" -gt 5 ]; then
    log_success "Spazio disco OK: ${DISK_SPACE}GB disponibili"
else
    log_warning "Poco spazio disco: ${DISK_SPACE}GB (raccomandato almeno 5GB per immagini Docker)"
fi

# Verifica memoria
MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
if [ "$MEMORY_GB" -gt 3 ]; then
    log_success "Memoria OK: ${MEMORY_GB}GB"
else
    log_warning "Poca memoria: ${MEMORY_GB}GB (raccomandato almeno 4GB per container multipli)"
fi

# Test Docker funzionalità
log_info "=== Test Funzionalità Docker ==="
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    log_info "Test container hello-world..."
    if docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker funziona correttamente"
    else
        log_error "Docker non funziona correttamente"
        MISSING_DEPS+=("Docker Test: Verificare installazione Docker")
    fi
fi

# Verifica connettività Docker Hub
log_info "Test connettività Docker Hub..."
if curl -s --connect-timeout 5 https://hub.docker.com >/dev/null; then
    log_success "Connettività Docker Hub OK"
else
    log_warning "Problemi connettività Docker Hub (potrebbero esserci problemi di download immagini)"
fi

# Installazione automatica dipendenze mancanti
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    log_error "Prerequisiti mancanti rilevati:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    
    echo ""
    read -p "Vuoi tentare l'installazione automatica? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Avvio installazione automatica..."
        
        # Aggiorna package manager
        sudo apt-get update
        
        # Installa Docker se mancante
        if ! command -v docker >/dev/null 2>&1; then
            log_info "Installazione Docker..."
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker "$USER"
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
        
        # Installa Docker Compose se mancante
        if ! command -v docker-compose >/dev/null 2>&1; then
            log_info "Installazione Docker Compose..."
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        log_success "Installazione automatica completata"
        log_warning "RIAVVIO NECESSARIO per applicare i permessi Docker"
    fi
fi

echo ""
echo "======================================="
echo "   VERIFICA PREREQUISITI COMPLETATA"
echo "======================================="

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    log_success "✓ Tutti i prerequisiti per FASE 2 sono soddisfatti!"
    echo ""
    echo "Sistema pronto per containerizzazione:"
    echo "- Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "- Docker Compose: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "- Node.js: $(node --version)"
    echo "- FASE 1: Prerequisiti soddisfatti"
    echo ""
    echo "Prossimi passi:"
    echo "1. ./deploy-containers.sh    # Avvia container"
    echo "2. ./test-containers.sh      # Test completi"
    echo ""
else
    log_error "Alcuni prerequisiti non sono soddisfatti"
    echo ""
    echo "Per procedere con FASE 2, risolvere:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Dopo aver risolto, rieseguire: ./prerequisites-docker.sh"
fi

log "Prerequisites Docker check completed"