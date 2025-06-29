#!/bin/bash

# prerequisites.sh (Refactored for PostgreSQL)
# Script per verificare e installare i prerequisiti per il CRM System
# FASE 1: Validazione Base con PostgreSQL

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"

NODE_MIN_VERSION="18.0.0"
LOG_FILE="$LOG_DIR/prerequisites.log"
PROJECT_DIR="$SCRIPT_DIR/.." # CORRETTO
BACKEND_DIR="$PROJECT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"

# Configurazioni Docker e DB
DB_CONTAINER_NAME="crm-postgres"
DB_IMAGE="postgres:16"
DB_USER="postgres"
DB_PASSWORD="admin123"
DB_NAME="crm"
DB_PORT="4002"

# --- COLORI E LOGGING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "$1"
}
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

# --- FUNZIONI DI VERIFICA ---

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

check_nodejs() {
    print_status "Verifica Node.js..."
    if ! command -v node &> /dev/null; then
        print_error "Node.js non trovato. Per favore, installalo (versione >= $NODE_MIN_VERSION)."
        return 1
    fi
    
    NODE_VERSION=$(node --version | sed 's/v//')
    if version_gt $NODE_VERSION $NODE_MIN_VERSION || [ "$NODE_VERSION" = "$NODE_MIN_VERSION" ]; then
        print_success "✓ Node.js trovato: v$NODE_VERSION"
        return 0
    else
        print_error "Node.js versione troppo vecchia. Richiesta: >= $NODE_MIN_VERSION, trovata: $NODE_VERSION."
        return 1
    fi
}

check_git() {
    print_status "Verifica Git..."
    if ! command -v git &> /dev/null; then
        print_error "Git non trovato. Per favore, installalo."
        return 1
    fi
    print_success "✓ Git trovato: $(git --version)"
}

check_docker() {
    print_status "Verifica Docker..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker non trovato. Per favore, installalo."
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        print_error "Il demone Docker non è in esecuzione. Avvialo per continuare."
        return 1
    fi
    
    print_success "✓ Docker trovato e in esecuzione."
}

start_postgres_container() {
    print_status "Verifica container database PostgreSQL..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
        if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
            print_success "✓ Container PostgreSQL '$DB_CONTAINER_NAME' è già in esecuzione."
            return 0
        else
            print_warning "Container PostgreSQL '$DB_CONTAINER_NAME' esiste ma è fermo. Lo avvio..."
            docker start "$DB_CONTAINER_NAME"
            print_success "✓ Container avviato."
        fi
    else
        print_warning "Container PostgreSQL '$DB_CONTAINER_NAME' non trovato. Lo creo e avvio..."
        docker run -d --name "$DB_CONTAINER_NAME" \
          -e POSTGRES_USER="$DB_USER" \
          -e POSTGRES_PASSWORD="$DB_PASSWORD" \
          -e POSTGRES_DB="$DB_NAME" \
          -p "$DB_PORT:5432" \
          -v "crm-pgdata:/var/lib/postgresql/data" \
          --restart unless-stopped \
          "$DB_IMAGE"
        print_success "✓ Container PostgreSQL creato e avviato."
    fi
    
    print_status "Attendo che il database sia pronto ad accettare connessioni..."
    sleep 5
}

create_env_file() {
    print_status "Verifica e creazione del file .env per il backend..."
    
    if [ -f "$ENV_FILE" ]; then
        print_success "✓ File .env già presente in $BACKEND_DIR."
    else
        print_warning "File .env non trovato. Lo creo con le impostazioni per il database locale..."
        cat > "$ENV_FILE" << EOL
# PostgreSQL Database Configuration
DB_HOST=localhost
DB_PORT=${DB_PORT}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_DATABASE=${DB_NAME}

# Application Port
PORT=4001

# Frontend URL for CORS
FRONTEND_URL=http://localhost:4000
EOL
        print_success "✓ File .env creato in $BACKEND_DIR."
    fi
}


# --- SCRIPT PRINCIPALE ---
echo -e "${BLUE}"
echo "======================================================"
echo "   CRM System - Prerequisites Check (PostgreSQL)"
echo "   FASE 1: Validazione Base"
echo "======================================================"
echo -e "${NC}"

rm -f "$LOG_FILE"
failed_checks=()

if ! check_git; then failed_checks+=("git"); fi
if ! check_nodejs; then failed_checks+=("nodejs"); fi
if ! check_docker; then failed_checks+=("docker"); fi

if [ ${#failed_checks[@]} -ne 0 ]; then
    print_error "Prerequisiti fondamentali mancanti: ${failed_checks[*]}. Impossibile continuare."
    exit 1
fi

start_postgres_container
create_env_file

echo -e "${GREEN}"
echo "======================================="
echo "   VERIFICA PREREQUISITI COMPLETATA"
echo "======================================="
echo -e "${NC}"
print_success "✓ Tutti i prerequisiti sono soddisfatti!"
echo ""
echo "Ambiente pronto:"
echo "  - Git, Node.js, Docker: OK"
echo "  - Container PostgreSQL '$DB_CONTAINER_NAME' in esecuzione sulla porta $DB_PORT."
echo "  - File di configurazione '$ENV_FILE' creato."
echo "  - Log di questo script in: $LOG_FILE"
echo ""
echo "Prossimi passi:"
echo "1. ./deploy.sh start   # Compila e avvia l'applicazione"
echo "2. ./test.sh           # Esegue i test di validazione"
echo ""
exit 0
