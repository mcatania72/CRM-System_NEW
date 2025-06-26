#!/bin/bash

# sync-devops-config.sh v2.0
# Script per sincronizzare la configurazione DevOps dalla repository GitHub
# Versione migliorata con verifica e rollback

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
echo "   CRM System - DevOps Sync Script v2.0"
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

# Funzione per verificare integrità file
verify_file_integrity() {
    local file_path="$1"
    local expected_min_size="$2"
    local file_name=$(basename "$file_path")
    
    if [ ! -f "$file_path" ]; then
        print_error "File $file_name non trovato"
        return 1
    fi
    
    local file_size=$(wc -l < "$file_path")
    if [ "$file_size" -lt "$expected_min_size" ]; then
        print_error "File $file_name troppo piccolo ($file_size righe, minimo $expected_min_size)"
        return 1
    fi
    
    print_success "✓ $file_name verificato ($file_size righe)"
    return 0
}

# Backup della configurazione esistente se presente
BACKUP_DIR=""
if [ -d "$DEVOPS_CONFIG_DIR" ]; then
    print_warning "Directory devops-pipeline-fase-1 esistente. Creando backup..."
    BACKUP_DIR="${DEVOPS_CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$DEVOPS_CONFIG_DIR" "$BACKUP_DIR"
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

# Verifica che la directory devops-pipeline-fase-1 esista nel repo
if [ ! -d "$PROJECT_DIR/devops-pipeline-fase-1" ]; then
    print_error "Directory devops-pipeline-fase-1 non trovata nel repository"
    exit 1
fi

# Rimuovi directory locale esistente
if [ -d "$DEVOPS_CONFIG_DIR" ]; then
    rm -rf "$DEVOPS_CONFIG_DIR"
fi

# Copiare la directory devops-pipeline-fase-1 nella home
print_status $BLUE "Copia configurazione DevOps..."
cp -r "$PROJECT_DIR/devops-pipeline-fase-1" "$HOME/"

# Rendere eseguibili tutti gli script
chmod +x "$HOME/devops-pipeline-fase-1"/*.sh

# Verifica integrità dei file con dimensioni minime attese
print_status $BLUE "Verifica integrità files..."

declare -A expected_sizes=(
    ["prerequisites.sh"]=50
    ["deploy.sh"]=200
    ["test.sh"]=250
    ["sync-devops-config.sh"]=50
)

all_files_ok=true

for file in "${!expected_sizes[@]}"; do
    if ! verify_file_integrity "$HOME/devops-pipeline-fase-1/$file" "${expected_sizes[$file]}"; then
        all_files_ok=false
    fi
done

# Se i file non sono OK, ripristina backup
if [ "$all_files_ok" = false ]; then
    print_error "Verifica integrità fallita!"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        rm -rf "$DEVOPS_CONFIG_DIR"
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# Verifica contenuto specifico test.sh (non deve avere set -e)
if grep -q "^set -e" "$HOME/devops-pipeline-fase-1/test.sh"; then
    print_error "test.sh contiene ancora 'set -e' - sync non aggiornato"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        rm -rf "$DEVOPS_CONFIG_DIR"
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
else
    print_success "✓ test.sh verificato - nessun 'set -e' trovato"
fi

# Rimuovi backup se tutto OK
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    print_success "Backup rimosso - sync completato con successo"
fi

# Creare symlink per facilità d'uso
if [ ! -L "$HOME/devops-scripts" ]; then
    ln -s "$HOME/devops-pipeline-fase-1" "$HOME/devops-scripts"
    print_status $GREEN "Symlink creato: ~/devops-scripts -> ~/devops-pipeline-fase-1"
fi

# Output informazioni dettagliate
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

# Mostra dettagli file sincronizzati
echo "File sincronizzati:"
for file in prerequisites.sh deploy.sh test.sh sync-devops-config.sh; do
    if [ -f "$HOME/devops-pipeline-fase-1/$file" ]; then
        local size=$(wc -l < "$HOME/devops-pipeline-fase-1/$file")
        echo "  ✓ $file ($size righe)"
    fi
done

echo ""
echo "Prossimi passi:"
echo "1. cd ~/devops-pipeline-fase-1"
echo "2. ./prerequisites.sh"
echo "3. ./deploy.sh"
echo "4. ./test.sh"
echo ""
print_success "Sync completato con successo!"

exit 0