#!/bin/bash

# Deploy Containers Script - FASE 2 (Refactored for PostgreSQL)
# Wrapper per gestire l'applicazione containerizzata con Docker Compose.

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-containers.log"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Porte da verificare
PORTS_TO_CHECK=("4000" "4001" "4002")

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

# --- FUNZIONI ---

check_and_free_ports() {
    print_status "Verifico porte necessarie: ${PORTS_TO_CHECK[*]}..."
    for port in "${PORTS_TO_CHECK[@]}"; do
        if lsof -ti:"$port" >/dev/null 2>&1; then
            print_warning "Porta $port è occupata. Tento di liberarla..."
            lsof -ti:"$port" | xargs -r kill -9
        fi
    done
    sleep 1
    print_success "✓ Porte verificate."
}

# Funzione per avviare i container
start_containers() {
    print_status "Avvio dell'intera applicazione con Docker Compose..."
    check_and_free_ports
    
    # Passa eventuali argomenti extra (es. --build) a docker-compose
    docker-compose -f "$COMPOSE_FILE" up -d --remove-orphans "$@"
    
    print_success "Comando di avvio inviato. Controllo lo stato dei servizi..."
    sleep 5
    show_status
}

# Funzione per fermare i container
stop_containers() {
    print_status "Fermo tutti i servizi gestiti da Docker Compose..."
    docker-compose -f "$COMPOSE_FILE" down --volumes
    print_success "Applicazione fermata e risorse pulite."
}

# Funzione per mostrare lo stato
show_status() {
    print_status "Stato dei container dell'applicazione:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo -e "\n${BLUE}[INFO]${NC} Accesso applicazione:"
    echo "  - Frontend: http://localhost:4000 (o IP della VM)"
    echo "  - Backend API: http://localhost:4001/api"
    echo "  - Database (esterno): localhost:4002"
}

# Funzione per vedere i log
show_logs() {
    print_status "Visualizzazione log in tempo reale (premi Ctrl+C per uscire)..."
    docker-compose -f "$COMPOSE_FILE" logs -f --tail="50"
}


# --- SCRIPT PRINCIPALE ---
COMMAND=$1
shift # Rimuove il primo argomento, lascia il resto per docker-compose

case "${COMMAND:-up}" in
    "up")
        start_containers "$@" # Passa gli argomenti rimanenti
        ;;
    "down")
        stop_containers
        ;;
    "restart")
        stop_containers
        sleep 2
        start_containers "$@"
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    *)
        echo "Uso: $0 {up|down|restart|status|logs} [docker-compose-options]"
        echo ""
        echo "Esempio: $0 up --build"
        echo ""
        exit 1
        ;;
esac