#!/bin/bash

# Prerequisites Docker Script - FASE 2 (Refactored for PostgreSQL)
# Verifica Docker, Docker Compose e libera le porte necessarie.

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/prerequisites-docker.log"

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

# --- FUNZIONI DI VERIFICA ---

check_command() {
    local cmd=$1
    local name=$2
    print_status "Verifico $name..."
    if command -v "$cmd" >/dev/null 2>&1; then
        print_success "✓ $name trovato"
        return 0
    else
        print_error "✗ $name non trovato. Per favore, installalo."
        return 1
    fi
}

check_docker_running() {
    print_status "Verifico che il demone Docker sia in esecuzione..."
    if ! docker info > /dev/null 2>&1; then
        print_error "✗ Il demone Docker non è in esecuzione. Avvialo per continuare."
        return 1
    fi
    print_success "✓ Docker è in esecuzione."
}

check_and_free_ports() {
    print_status "Verifico porte necessarie: ${PORTS_TO_CHECK[*]}..."
    local port_found=false
    for port in "${PORTS_TO_CHECK[@]}"; do
        if lsof -ti:"$port" >/dev/null 2>&1; then
            print_warning "Porta $port è occupata. Tento di liberarla..."
            lsof -ti:"$port" | xargs -r kill -9
            sleep 1
            if lsof -ti:"$port" >/dev/null 2>&1; then
                print_error "✗ Impossibile liberare la porta $port."
                port_found=true
            else
                print_success "✓ Porta $port liberata."
            fi
        fi
    done

    if [ "$port_found" = true ]; then
        return 1
    fi
    print_success "✓ Tutte le porte necessarie sono libere."
    return 0
}

# --- SCRIPT PRINCIPALE ---
echo -e "${BLUE}"
echo "======================================================"
echo "   CRM System - Prerequisites Docker (PostgreSQL)"
echo "   FASE 2: Containerizzazione Completa"
echo "======================================================"
echo -e "${NC}"

rm -f "$LOG_FILE"
failed_checks=()

# Esecuzione dei controlli
if ! check_command "docker" "Docker"; then failed_checks+=("Docker"); fi
if ! check_command "docker-compose" "Docker Compose"; then failed_checks+=("Docker Compose"); fi

if [ ${#failed_checks[@]} -ne 0 ]; then
    print_error "Prerequisiti fondamentali mancanti. Impossibile continuare."
    exit 1
fi

if ! check_docker_running; then exit 1; fi
if ! check_and_free_ports; then exit 1; fi

# Riepilogo finale
echo -e "${GREEN}"
echo "======================================="
echo "   VERIFICA PREREQUISITI COMPLETATA"
echo "======================================="
echo -e "${NC}"
print_success "✓ Tutti i prerequisiti per la Fase 2 sono soddisfatti!"
echo ""
echo "Sistema pronto per la containerizzazione."
echo "Log di questo script in: $LOG_FILE"
echo ""
echo "Prossimi passi:"
echo "1. ./deploy-containers.sh up   # Avvia l'intera applicazione con Docker Compose"
echo "2. ./test-containers.sh       # Esegue i test sui container"
echo ""
exit 0
