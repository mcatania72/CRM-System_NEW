#!/bin/bash

# CRM System Test Script (Refactored for PostgreSQL)
# FASE 1: Validazione Base

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"

PROJECT_DIR="$SCRIPT_DIR/.." # CORRETTO
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

LOG_FILE="$LOG_DIR/test.log"
TEST_REPORT_DIR="$LOG_DIR/test-reports"
BACKEND_LOG="$LOG_DIR/backend_test.log"
BACKEND_PID_FILE="$LOG_DIR/backend_test.pid"
DB_CONTAINER_NAME="crm-postgres"
BACKEND_PORT="4001"

# --- COLORI E LOGGING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# --- FUNZIONI DI TEST ---

run_unit_tests() {
    local service_dir=$1
    local service_name=$2
    
    log_info "--- Inizio Test Unitari $service_name ---"
    cd "$service_dir"
    
    if [[ ! -d "node_modules" ]]; then
        log_info "Installazione dipendenze $service_name..."
        npm install
    fi
    
    log_info "Esecuzione test unitari per $service_name..."
    if npm test -- --reporters=default --reporters=jest-junit; then
        log_success "✓ Test unitari $service_name completati"
        if [[ -f "junit.xml" ]]; then
            mv junit.xml "$TEST_REPORT_DIR/${service_name,,}-junit.xml"
        fi
        return 0
    else
        log_error "✗ Test unitari $service_name falliti"
        return 1
    fi
}

run_backend_smoke_test() {
    log_info "--- Inizio Smoke Test Backend (Connessione DB) ---"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
        log_error "Database '$DB_CONTAINER_NAME' non in esecuzione. Impossibile eseguire lo smoke test."
        return 1
    fi
    
    cd "$BACKEND_DIR"
    log_info "Avvio temporaneo del backend per lo smoke test..."
    nohup npm run dev > "$BACKEND_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$BACKEND_PID_FILE"
    
    log_info "Attendo 10 secondi per l'avvio del backend..."
    sleep 10
    
    local test_passed=false
    if ps -p $pid > /dev/null; then
        if grep -q "Database connesso con successo" "$BACKEND_LOG"; then
            log_success "✓ Smoke Test: Il backend si è connesso al database."
            test_passed=true
        else
            log_error "✗ Smoke Test: Messaggio di connessione al DB non trovato nei log."
        fi
    else
        log_error "✗ Smoke Test: Il backend non è riuscito ad avviarsi."
    fi
    
    log_info "Fermo il backend temporaneo..."
    kill -TERM $pid 2>/dev/null || true
    sleep 2
    kill -KILL $pid 2>/dev/null || true
    rm -f "$BACKEND_PID_FILE"
    
    if [[ "$test_passed" = true ]]; then
        return 0
    else
        log_error "Log del backend per il debug:"
        cat "$BACKEND_LOG"
        return 1
    fi
}

# --- SCRIPT PRINCIPALE ---
echo -e "\n=======================================\n   CRM System - Test Script (PostgreSQL)\n======================================="
rm -f "$LOG_FILE"
mkdir -p "$TEST_REPORT_DIR"

failed_tests=()

if ! run_unit_tests "$BACKEND_DIR" "Backend"; then failed_tests+=("Backend Unit Tests"); fi
echo ""
if ! run_unit_tests "$FRONTEND_DIR" "Frontend"; then failed_tests+=("Frontend Unit Tests"); fi
echo ""
if ! run_backend_smoke_test; then failed_tests+=("Backend Smoke Test"); fi

echo -e "\n=======================================\n   RIEPILOGO TEST\n======================================="
if [ ${#failed_tests[@]} -eq 0 ]; then
    log_success "✓ Tutti i test sono stati completati con successo!"
    echo "Report JUnit generati in: $TEST_REPORT_DIR"
    exit 0
else
    log_error "✗ Alcuni test sono falliti:"
    for test in "${failed_tests[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    echo -e "\nControllare il log per i dettagli: $LOG_FILE"
    exit 1
fi
