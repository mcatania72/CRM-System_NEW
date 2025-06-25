#!/bin/bash

# prerequisites.sh
# Script per verificare e installare i prerequisiti per il CRM System
# FASE 1: Validazione Base

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
NODE_MIN_VERSION="18.0.0"
NPM_MIN_VERSION="8.0.0"
LOG_FILE="$HOME/prerequisites.log"
PROJECT_DIR="$HOME/devops/CRM-System"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funzioni per output colorato
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

# Funzione per confrontare versioni
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Funzione per installare Node.js tramite NodeSource
install_nodejs() {
    print_status $BLUE "Installazione Node.js tramite NodeSource..."
    
    # Update system
    sudo apt-get update
    
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        sudo apt-get install -y curl
    fi
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    
    # Install Node.js
    sudo apt-get install -y nodejs
    
    print_success "Node.js installato con successo"
}

# Funzione per verificare Node.js
check_nodejs() {
    print_status $BLUE "Verifica Node.js..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//')
        print_status $GREEN "Node.js trovato: v$NODE_VERSION"
        
        if version_gt $NODE_VERSION $NODE_MIN_VERSION || [ "$NODE_VERSION" = "$NODE_MIN_VERSION" ]; then
            print_success "✓ Node.js versione compatibile (>= $NODE_MIN_VERSION)"
            return 0
        else
            print_warning "Node.js versione troppo vecchia. Richiesta: >= $NODE_MIN_VERSION, trovata: $NODE_VERSION"
            return 1
        fi
    else
        print_warning "Node.js non trovato"
        return 1
    fi
}

# Funzione per verificare npm
check_npm() {
    print_status $BLUE "Verifica npm..."
    
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_status $GREEN "npm trovato: v$NPM_VERSION"
        
        if version_gt $NPM_VERSION $NPM_MIN_VERSION || [ "$NPM_VERSION" = "$NPM_MIN_VERSION" ]; then
            print_success "✓ npm versione compatibile (>= $NPM_MIN_VERSION)"
            return 0
        else
            print_warning "npm versione troppo vecchia. Aggiornamento..."
            sudo npm install -g npm@latest
            print_success "npm aggiornato"
            return 0
        fi
    else
        print_error "npm non trovato (dovrebbe essere installato con Node.js)"
        return 1
    fi
}

# Funzione per verificare Git
check_git() {
    print_status $BLUE "Verifica Git..."
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | cut -d' ' -f3)
        print_success "✓ Git trovato: v$GIT_VERSION"
        return 0
    else
        print_warning "Git non trovato. Installazione..."
        sudo apt-get update && sudo apt-get install -y git
        print_success "Git installato"
        return 0
    fi
}

# Funzione per verificare build tools
check_build_tools() {
    print_status $BLUE "Verifica build tools..."
    
    # Check for Python (needed for some npm packages)
    if ! command -v python3 &> /dev/null; then
        print_warning "Python3 non trovato. Installazione..."
        sudo apt-get install -y python3 python3-pip
    else
        print_success "✓ Python3 trovato"
    fi
    
    # Check for build-essential
    if ! dpkg -l | grep -q build-essential; then
        print_warning "build-essential non trovato. Installazione..."
        sudo apt-get install -y build-essential
    else
        print_success "✓ build-essential trovato"
    fi
    
    # Check for make
    if ! command -v make &> /dev/null; then
        print_warning "make non trovato. Installazione..."
        sudo apt-get install -y make
    else
        print_success "✓ make trovato"
    fi
}

# Funzione per verificare la directory del progetto
check_project_directory() {
    print_status $BLUE "Verifica directory progetto..."
    
    if [ -d "$PROJECT_DIR" ]; then
        print_success "✓ Directory progetto trovata: $PROJECT_DIR"
        
        # Verifica struttura progetto
        if [ -f "$PROJECT_DIR/package.json" ] && [ -d "$PROJECT_DIR/backend" ] && [ -d "$PROJECT_DIR/frontend" ]; then
            print_success "✓ Struttura progetto valida"
            return 0
        else
            print_error "Struttura progetto non valida"
            return 1
        fi
    else
        print_error "Directory progetto non trovata: $PROJECT_DIR"
        print_status $YELLOW "Eseguire prima: ./sync-devops-config.sh"
        return 1
    fi
}

# Funzione per verificare permessi
check_permissions() {
    print_status $BLUE "Verifica permessi..."
    
    # Check if user can write to project directory
    if [ -w "$PROJECT_DIR" ]; then
        print_success "✓ Permessi di scrittura OK"
    else
        print_warning "Permessi di scrittura mancanti per $PROJECT_DIR"
        sudo chown -R $USER:$USER "$PROJECT_DIR"
        print_success "Permessi corretti"
    fi
}

# Funzione per test di connettività
check_connectivity() {
    print_status $BLUE "Test connettività..."
    
    # Test npm registry
    if curl -s --connect-timeout 10 https://registry.npmjs.org/ > /dev/null; then
        print_success "✓ Connessione a npm registry OK"
    else
        print_warning "Problemi di connessione a npm registry"
    fi
    
    # Test GitHub
    if curl -s --connect-timeout 10 https://github.com > /dev/null; then
        print_success "✓ Connessione a GitHub OK"
    else
        print_warning "Problemi di connessione a GitHub"
    fi
}

# Banner
echo -e "${BLUE}"
echo "======================================="
echo "   CRM System - Prerequisites Check"
echo "   FASE 1: Validazione Base"
echo "======================================="
echo -e "${NC}"

print_status $BLUE "Verifica prerequisiti per CRM System..."

# Array per tracciare i controlli falliti
failed_checks=()

# Aggiornamento system packages
print_status $BLUE "Aggiornamento repository di sistema..."
sudo apt-get update -qq

# Verifica prerequisiti di sistema
if ! check_git; then
    failed_checks+=("git")
fi

if ! check_nodejs; then
    print_status $YELLOW "Installazione Node.js..."
    install_nodejs
    if ! check_nodejs; then
        failed_checks+=("nodejs")
    fi
fi

if ! check_npm; then
    failed_checks+=("npm")
fi

check_build_tools
check_connectivity

if ! check_project_directory; then
    failed_checks+=("project_directory")
fi

if [ -d "$PROJECT_DIR" ]; then
    check_permissions
fi

# Installazione dipendenze globali utili
print_status $BLUE "Installazione strumenti globali..."
npm install -g typescript ts-node@latest 2>/dev/null || print_warning "Errore installazione strumenti globali"

# Summary
echo -e "${GREEN}"
echo "======================================="
echo "   VERIFICA PREREQUISITI COMPLETATA"
echo "======================================="
echo -e "${NC}"

if [ ${#failed_checks[@]} -eq 0 ]; then
    print_success "✓ Tutti i prerequisiti sono soddisfatti!"
    echo ""
    echo "Sistema pronto per:"
    echo "- Node.js: $(node --version)"
    echo "- npm: v$(npm --version)"
    echo "- Git: $(git --version | cut -d' ' -f3)"
    echo "- Python3: $(python3 --version 2>/dev/null || echo 'non disponibile')"
    echo ""
    echo "Prossimi passi:"
    echo "1. ./deploy.sh    # Compila e avvia l'applicazione"
    echo "2. ./test.sh      # Esegue i test di validazione"
    echo ""
    log "Prerequisites check completed successfully"
    exit 0
else
    print_error "Alcuni prerequisiti non sono soddisfatti:"
    for check in "${failed_checks[@]}"; do
        echo -e "${RED}  ✗ $check${NC}"
    done
    echo ""
    echo "Risolvere i problemi sopra indicati prima di continuare."
    log "Prerequisites check failed: ${failed_checks[*]}"
    exit 1
fi