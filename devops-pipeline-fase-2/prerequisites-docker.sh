#!/bin/bash

# Prerequisites Docker Script - FASE 2
# Verifica Docker, Docker Compose e altri prerequisiti per containerizzazione
# Installazione automatica delle dipendenze mancanti

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

# Array per tracciare i prerequisiti da installare
INSTALL_DOCKER=false
INSTALL_COMPOSE=false
MISSING_DEPS=()

# Funzione per verificare comandi
check_command() {
    local cmd=$1
    local name=$2
    
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
                version=$(command -v "$cmd" && echo "installato")
                ;;
        esac
        log_success "$name trovato: $version"
        return 0
    else
        log_error "$name non trovato"
        return 1
    fi
}

# Funzione per installare Docker
install_docker() {
    log_info "🚀 Installazione Docker..."
    
    # Aggiorna package manager
    sudo apt-get update
    
    # Installa prerequisiti per HTTPS
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Aggiungi GPG key ufficiale Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Aggiungi repository Docker
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Aggiorna e installa Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Aggiungi utente al gruppo docker
    sudo usermod -aG docker "$USER"
    
    # Abilita e avvia servizio
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_success "Docker installato con successo"
    log_warning "RIAVVIO NECESSARIO per applicare i permessi Docker (oppure: newgrp docker)"
}

# Funzione per installare Docker Compose
install_docker_compose() {
    log_info "🚀 Installazione Docker Compose..."
    
    # Metodo 1: Prova con apt (Ubuntu 20.04+)
    if sudo apt-get install -y docker-compose-plugin 2>/dev/null; then
        log_success "Docker Compose Plugin installato via apt"
        
        # Crea symlink per retrocompatibilità
        if [ ! -f "/usr/local/bin/docker-compose" ]; then
            sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
        fi
    else
        log_info "Apt package non disponibile, scarico binary manualmente..."
        
        # Metodo 2: Download diretto binary
        # Ottieni ultima versione
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        
        if [ -z "$COMPOSE_VERSION" ]; then
            log_warning "Impossibile ottenere ultima versione, uso v2.24.1"
            COMPOSE_VERSION="v2.24.1"
        fi
        
        log_info "Scarico Docker Compose $COMPOSE_VERSION..."
        
        # Download binary
        sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        
        # Rendi eseguibile
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Verifica installazione
        if /usr/local/bin/docker-compose --version >/dev/null 2>&1; then
            log_success "Docker Compose $COMPOSE_VERSION installato manualmente"
        else
            log_error "Errore nell'installazione manuale Docker Compose"
            return 1
        fi
    fi
    
    # Verifica finale
    if command -v docker-compose >/dev/null 2>&1; then
        local version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker Compose verificato: $version"
    else
        log_error "Docker Compose non trovato dopo installazione"
        return 1
    fi
}

# Verifica prerequisiti base (dalla FASE 1)
log_info "=== Prerequisiti Base (FASE 1) ==="
check_command "node" "Node.js" || MISSING_DEPS+=("Node.js")
check_command "npm" "npm" || MISSING_DEPS+=("npm")
check_command "git" "Git" || MISSING_DEPS+=("Git")
check_command "curl" "curl" || MISSING_DEPS+=("curl")
check_command "sqlite3" "SQLite3" || MISSING_DEPS+=("SQLite3")

# Verifica prerequisiti Docker (FASE 2)
log_info "=== Prerequisiti Docker (FASE 2) ==="

# Verifica Docker
if ! check_command "docker" "Docker"; then
    INSTALL_DOCKER=true
    MISSING_DEPS+=("Docker")
fi

# Verifica Docker Compose
if ! check_command "docker-compose" "Docker Compose"; then
    INSTALL_COMPOSE=true
    MISSING_DEPS+=("Docker Compose")
fi

# Installazione automatica
if [ "$INSTALL_DOCKER" = true ] || [ "$INSTALL_COMPOSE" = true ] || [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    log_warning "Prerequisiti mancanti rilevati:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    
    echo ""
    log_info "🚀 AVVIO INSTALLAZIONE AUTOMATICA..."
    echo ""
    
    # Aggiorna package manager
    log_info "Aggiornamento package manager..."
    sudo apt-get update
    
    # Installa prerequisiti base mancanti
    if [[ " ${MISSING_DEPS[@]} " =~ " Git " ]]; then
        log_info "Installazione Git..."
        sudo apt-get install -y git
    fi
    
    if [[ " ${MISSING_DEPS[@]} " =~ " curl " ]]; then
        log_info "Installazione curl..."
        sudo apt-get install -y curl
    fi
    
    if [[ " ${MISSING_DEPS[@]} " =~ " SQLite3 " ]]; then
        log_info "Installazione SQLite3..."
        sudo apt-get install -y sqlite3
    fi
    
    if [[ " ${MISSING_DEPS[@]} " =~ " Node.js " ]]; then
        log_info "Installazione Node.js 18..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # Installa Docker se mancante
    if [ "$INSTALL_DOCKER" = true ]; then
        install_docker
    fi
    
    # Installa Docker Compose se mancante
    if [ "$INSTALL_COMPOSE" = true ]; then
        install_docker_compose
    fi
    
    log_success "🎉 Installazione automatica completata!"
fi

# Verifica servizio Docker
if command -v docker >/dev/null 2>&1; then
    log_info "Verifico servizio Docker..."
    if systemctl is-active --quiet docker; then
        log_success "Servizio Docker attivo"
    else
        log_warning "Servizio Docker non attivo, provo ad avviarlo..."
        if sudo systemctl start docker; then
            log_success "Servizio Docker avviato"
        else
            log_error "Impossibile avviare servizio Docker"
            MISSING_DEPS+=("Docker Service")
        fi
    fi
    
    # Verifica permessi Docker
    log_info "Verifico permessi Docker..."
    if docker ps >/dev/null 2>&1; then
        log_success "Permessi Docker OK"
    else
        log_warning "Permessi Docker insufficienti"
        log_info "Aggiungo utente al gruppo docker..."
        sudo usermod -aG docker "$USER"
        log_warning "⚠️  RIAVVIO NECESSARIO: Effettua logout/login o riavvia per applicare i permessi Docker"
        log_info "💡 Oppure usa temporaneamente: newgrp docker"
    fi
fi

# Verifica versioni minime
if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
    log_info "=== Verifica Versioni Minime ==="
    
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ "$(printf '%s\n' "20.10" "$DOCKER_VERSION" | sort -V | head -n1)" = "20.10" ]; then
        log_success "Docker versione OK: $DOCKER_VERSION (>= 20.10)"
    else
        log_warning "Docker versione troppo vecchia: $DOCKER_VERSION (raccomandato >= 20.10)"
    fi
    
    COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ "$(printf '%s\n' "1.29" "$COMPOSE_VERSION" | sort -V | head -n1)" = "1.29" ]; then
        log_success "Docker Compose versione OK: $COMPOSE_VERSION (>= 1.29)"
    else
        log_warning "Docker Compose versione troppo vecchia: $COMPOSE_VERSION (raccomandato >= 1.29)"
    fi
fi

# Verifica risorse sistema
log_info "=== Verifica Risorse Sistema ==="
DISK_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_SPACE" -gt 5 ]; then
    log_success "Spazio disco OK: ${DISK_SPACE}GB disponibili"
else
    log_warning "Poco spazio disco: ${DISK_SPACE}GB (raccomandato almeno 5GB per immagini Docker)"
fi

MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
if [ "$MEMORY_GB" -gt 3 ]; then
    log_success "Memoria OK: ${MEMORY_GB}GB"
else
    log_warning "Poca memoria: ${MEMORY_GB}GB (raccomandato almeno 4GB per container multipli)"
fi

# Test Docker funzionalità
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    log_info "=== Test Funzionalità Docker ==="
    log_info "Test container hello-world..."
    if docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker funziona correttamente"
    else
        log_error "Docker non funziona correttamente"
        MISSING_DEPS+=("Docker Test")
    fi
    
    # Test Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        log_info "Test Docker Compose..."
        if docker-compose --version >/dev/null 2>&1; then
            log_success "Docker Compose funziona correttamente"
        else
            log_error "Docker Compose non funziona correttamente"
            MISSING_DEPS+=("Docker Compose Test")
        fi
    fi
fi

# Verifica connettività Docker Hub
log_info "Test connettività Docker Hub..."
if curl -s --connect-timeout 5 https://hub.docker.com >/dev/null; then
    log_success "Connettività Docker Hub OK"
else
    log_warning "Problemi connettività Docker Hub (potrebbero esserci problemi di download immagini)"
fi

echo ""
echo "======================================="
echo "   VERIFICA PREREQUISITI COMPLETATA"
echo "======================================="

# Ricalcola prerequisiti mancanti dopo installazione
FINAL_MISSING=()
command -v docker >/dev/null 2>&1 || FINAL_MISSING+=("Docker")
command -v docker-compose >/dev/null 2>&1 || FINAL_MISSING+=("Docker Compose")

if [ ${#FINAL_MISSING[@]} -eq 0 ]; then
    log_success "✅ Tutti i prerequisiti per FASE 2 sono soddisfatti!"
    echo ""
    echo "Sistema pronto per containerizzazione:"
    echo "- Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "- Docker Compose: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "- Node.js: $(node --version)"
    echo "- FASE 1: Prerequisiti soddisfatti"
    echo ""
    
    if ! docker ps >/dev/null 2>&1; then
        log_warning "⚠️  AZIONE RICHIESTA:"
        echo "Docker è installato ma serve riavvio per i permessi."
        echo "Opzioni:"
        echo "1. 🔄 Riavvia la VM: sudo reboot"
        echo "2. 🔄 Logout/Login: exit e riconnettiti"
        echo "3. 🔄 Gruppo temporaneo: newgrp docker"
        echo ""
        echo "Dopo il riavvio, esegui:"
    else
        echo "Prossimi passi:"
    fi
    echo "1. ./deploy-containers.sh    # Avvia container"
    echo "2. ./test-containers.sh      # Test completi"
    echo ""
else
    log_error "❌ Alcuni prerequisiti non sono soddisfatti"
    echo ""
    echo "Per procedere con FASE 2, risolvere:"
    for dep in "${FINAL_MISSING[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Riprova: ./prerequisites-docker.sh"
fi

log "Prerequisites Docker check completed"