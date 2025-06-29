#!/bin/bash

# Test Containers Script - FASE 2 (Refactored for PostgreSQL) - v3 (Patient)
# Esegue test di validazione sull'ambiente containerizzato.

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/test-containers.log"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
HEALTH_CHECK_RETRIES=12
HEALTH_CHECK_INTERVAL=5

# --- COLORI E LOGGING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ... (funzioni di logging invariate) ...
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

# --- FUNZIONI DI TEST ---

check_container_health_patiently() {
    print_status "Verifica paziente dello stato di salute dei container (max ${HEALTH_CHECK_RETRIES} tentativi)..."
    
    local services
    services=$(docker-compose -f "$COMPOSE_FILE" config --services)
    
    for service in $services; do
        local attempt=0
        while [ $attempt -lt $HEALTH_CHECK_RETRIES ]; do
            local health
            health=$(docker-compose -f "$COMPOSE_FILE" ps -q "$service" | xargs docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}not-defined{{end}}' 2>/dev/null || echo "error")
            
            if [ "$health" == "healthy" ] || [ "$health" == "not-defined" ]; then
                print_success "✓ Servizio '$service' è pronto (stato: $health)."
                break # Esce dal while, passa al prossimo servizio
            fi
            
            attempt=$((attempt + 1))
            print_warning "Servizio '$service' non ancora pronto (stato: $health). Attendo ${HEALTH_CHECK_INTERVAL}s... (Tentativo $attempt/$HEALTH_CHECK_RETRIES)"
            sleep $HEALTH_CHECK_INTERVAL
        done

        if [ $attempt -eq $HEALTH_CHECK_RETRIES ]; then
            print_error "✗ Servizio '$service' non è diventato healthy in tempo."
            return 1
        fi
    done
    
    return 0
}

run_api_login_test() {
    print_status "Esecuzione API Login Test..."
    
    response_code=$(curl --silent --output /dev/null --write-out '%{http_code}' \
        --request POST 'http://localhost:4001/api/auth/login' \
        --header 'Content-Type: application/json' \
        --data '{"email":"admin@crm.local","password":"admin123"}')

    if [ "$response_code" -eq 200 ]; then
        print_success "✓ API Login Test superato (HTTP $response_code)."
        return 0
    else
        print_error "✗ API Login Test fallito (HTTP $response_code)."
        return 1
    fi
}

# --- SCRIPT PRINCIPALE ---
echo -e "${BLUE}"
echo "======================================================"
echo "   CRM System - Test Containers (PostgreSQL)"
echo "   FASE 2: Containerizzazione Completa"
echo "======================================================"
echo -e "${NC}"

rm -f "$LOG_FILE"
failed_tests=()

if ! check_container_health_patiently; then failed_tests+=("Health Check Container"); fi
if ! run_api_login_test; then failed_tests+=("API Login Test"); fi

echo -e "\n=======================================\n   RIEPILOGO TEST CONTAINER\n======================================="
if [ ${#failed_tests[@]} -eq 0 ]; then
    print_success "✓ Tutti i test sui container sono stati completati con successo!"
    exit 0
else
    print_error "✗ Alcuni test sui container sono falliti:"
    for test in "${failed_tests[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    exit 1
fi