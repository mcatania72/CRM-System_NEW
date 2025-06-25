#!/bin/bash

# sync-devops-config.sh
# Script per sincronizzare la configurazione DevOps dalla repository GitHub
# Cancella il contenuto locale e scarica l'ultima versione

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
REPO_URL="https://github.com/mcatania72/CRM-System.git"
PROJECT_DIR="$HOME/devops/CRM-System"
DEVOPS_CONFIG_DIR="$HOME/devops-pipeline-fase-1"
LOG_FILE="$HOME/sync-devops.log"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funzione per output colorato
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[INFO]${NC} $message"
    log "$message"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

# Banner
echo -e "${BLUE}"
echo "======================================="
echo "   CRM System - DevOps Sync Script"
echo "   FASE 1: Validazione Base"
echo "======================================="
echo -e "${NC}"

print_status $BLUE "Inizializzazione sync DevOps config..."

# Verifica prerequisiti
if ! command -v git &> /dev/null; then
    print_error "Git non è installato. Installare git prima di continuare."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    print_error "Curl non è installato. Installare curl prima di continuare."
    exit 1
fi

# Backup della configurazione esistente se presente
if [ -d "$DEVOPS_CONFIG_DIR" ]; then
    print_warning "Directory devops-pipeline-fase-1 esistente. Creando backup..."
    BACKUP_DIR="${DEVOPS_CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    mv "$DEVOPS_CONFIG_DIR" "$BACKUP_DIR"
    print_status $YELLOW "Backup creato in: $BACKUP_DIR"
fi

# Creare la directory devops se non esiste
mkdir -p "$HOME/devops"

# Rimuovere directory progetto esistente se presente
if [ -d "$PROJECT_DIR" ]; then
    print_status $YELLOW "Rimozione directory progetto esistente..."
    rm -rf "$PROJECT_DIR"
fi

# Clone fresh del repository
print_status $BLUE "Clone del repository CRM-System..."
if git clone "$REPO_URL" "$PROJECT_DIR"; then
    print_success "Repository clonato con successo"
else
    print_error "Errore durante il clone del repository"
    exit 1
fi

# Copiare la directory devops-pipeline-fase-1 nella home
if [ -d "$PROJECT_DIR/devops-pipeline-fase-1" ]; then
    print_status $BLUE "Copia configurazione DevOps..."
    cp -r "$PROJECT_DIR/devops-pipeline-fase-1" "$HOME/"
    
    # Rendere eseguibili tutti gli script
    chmod +x "$HOME/devops-pipeline-fase-1"/*.sh
    
    print_success "Configurazione DevOps sincronizzata con successo"
else
    print_error "Directory devops-pipeline-fase-1 non trovata nel repository"
    exit 1
fi

# Verifica integrità dei file
print_status $BLUE "Verifica integrità files..."
required_files=(
    "prerequisites.sh"
    "deploy.sh"
    "test.sh"
    "sync-devops-config.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$HOME/devops-pipeline-fase-1/$file" ]; then
        print_success "✓ $file presente"
    else
        print_error "✗ $file mancante"
        exit 1
    fi
done

# Creare symlink per facilità d'uso
if [ ! -L "$HOME/devops-scripts" ]; then
    ln -s "$HOME/devops-pipeline-fase-1" "$HOME/devops-scripts"
    print_status $GREEN "Symlink creato: ~/devops-scripts -> ~/devops-pipeline-fase-1"
fi

# Output informazioni
echo -e "${GREEN}"
echo "======================================="
echo "   SINCRONIZZAZIONE COMPLETATA"
echo "======================================="
echo -e "${NC}"
echo "Directory progetto: $PROJECT_DIR"
echo "Directory DevOps: $HOME/devops-pipeline-fase-1"
echo "Symlink: $HOME/devops-scripts"
echo "Log file: $LOG_FILE"
echo ""
echo "Prossimi passi:"
echo "1. cd ~/devops-pipeline-fase-1"
echo "2. ./prerequisites.sh"
echo "3. ./deploy.sh"
echo "4. ./test.sh"
echo ""
print_success "Sync completato con successo!"

exit 0