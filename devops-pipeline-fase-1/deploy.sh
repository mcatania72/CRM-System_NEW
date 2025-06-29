#!/bin/bash

# CRM System Deploy Script (Refactored for PostgreSQL)
# FASE 1: Validazione Base - VERSIONE CORRETTA

set -e

# --- CONFIGURAZIONE ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_DIR="$SCRIPT_DIR/.logs"
mkdir -p "$LOG_DIR"

PROJECT_DIR="$SCRIPT_DIR/.." # CORRETTO
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

LOG_FILE="$LOG_DIR/deploy.log"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"
BACKEND_PID_FILE="$LOG_DIR/backend.pid"
FRONTEND_PID_FILE="$LOG_DIR/frontend.pid"

# Porte e DB
FRONTEND_PORT="4000"
BACKEND_PORT="4001"
DB_CONTAINER_NAME="crm-postgres"

# --- COLORI E LOGGING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# --- FUNZIONI DI GESTIONE PROCESSI ---

is_process_running() {
    local pid_file=$1
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

stop_process() {
    local pid_file=$1
    local service_name=$2
    if is_process_running "$pid_file"; then
        local pid
        pid=$(cat "$pid_file")
        log_info "Fermando $service_name (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null || true
        sleep 3
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warning "$service_name non si ferma, forzo terminazione..."
            kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
        log_success "$service_name fermato"
    else
        log_info "$service_name non è in esecuzione"
    fi
}

check_and_free_ports() {
    log_info "Verifico porte $FRONTEND_PORT e $BACKEND_PORT..."
    for port in $FRONTEND_PORT $BACKEND_PORT; do
        if lsof -ti:"$port" >/dev/null 2>&1; then
            log_warning "Porta $port occupata, libero..."
            lsof -ti:"$port" | xargs -r kill -9
        fi
    done
    sleep 2
}

# --- FUNZIONI DI AVVIO E STATUS ---

show_status() {
    echo -e "\n=======================================\n   CRM System - Status Check\n======================================="
    
    if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
        log_success "Database PostgreSQL '$DB_CONTAINER_NAME' in esecuzione"
    else
        log_error "Database PostgreSQL '$DB_CONTAINER_NAME' non in esecuzione!"
        log_warning "Avviare i prerequisiti con: ./prerequisites.sh"
    fi
    echo ""

    if is_process_running "$BACKEND_PID_FILE"; then
        local backend_pid
        backend_pid=$(cat "$BACKEND_PID_FILE")
        log_success "Backend in esecuzione (PID: $backend_pid)"
        if curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
            log_success "Backend risponde correttamente al health check"
        else
            log_warning "Backend non risponde al health check"
        fi
    else
        log_error "Backend non in esecuzione"
    fi
    echo ""

    if is_process_running "$FRONTEND_PID_FILE"; then
        local frontend_pid
        frontend_pid=$(cat "$FRONTEND_PID_FILE")
        log_success "Frontend in esecuzione (PID: $frontend_pid)"
        if curl -s "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
            log_success "Frontend risponde correttamente"
        else
            log_warning "Frontend non risponde"
        fi
    else
        log_error "Frontend non in esecuzione"
    fi
    
    echo -e "\n${BLUE}[INFO]${NC} Accesso applicazione:"
    echo "  - Frontend: http://localhost:$FRONTEND_PORT"
    echo "  - Backend API: http://localhost:$BACKEND_PORT/api"
    echo "  - Health Check: http://localhost:$BACKEND_PORT/api/health"
    echo -e "\nCredenziali di accesso: admin@crm.local / admin123\n"
}

start_backend() {
    log_info "Avvio backend..."
    cd "$BACKEND_DIR"
    
    if [[ ! -f ".env" ]]; then
        log_error "File .env non trovato! Eseguire prima ./prerequisites.sh"
        return 1
    fi
    
    if [[ ! -d "node_modules" ]]; then
        log_info "Installazione dipendenze backend..."
        npm install
    fi
    
    log_info "Avvio backend in modalità SVILUPPO (ts-node)..."
    nohup npm run dev > "$BACKEND_LOG" 2>&1 &
    
    local backend_pid=$!
    echo "$backend_pid" > "$BACKEND_PID_FILE"
    
    log_info "Attendo che il backend si avvii (PID: $backend_pid)..."
    sleep 8
    
    if ! is_process_running "$BACKEND_PID_FILE"; then
        log_error "Backend non riuscito ad avviarsi. Controllare $BACKEND_LOG"
        return 1
    fi
    
    if curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
        log_success "Backend avviato e health check OK"
        return 0
    else
        log_error "Backend avviato ma health check fallito. Controllare $BACKEND_LOG"
        return 1
    fi
}

start_frontend() {
    log_info "Avvio frontend..."
    cd "$FRONTEND_DIR"
    
    if [[ ! -d "node_modules" ]]; then
        log_info "Installazione dipendenze frontend..."
        npm install
    fi
    
    log_info "Avvio frontend in modalità SVILUPPO (vite dev)..."
    nohup npm run dev > "$FRONTEND_LOG" 2>&1 &
    
    local frontend_pid=$!
    echo "$frontend_pid" > "$FRONTEND_PID_FILE"
    
    log_info "Attendo che il frontend si avvii (PID: $frontend_pid)..."
    sleep 8
    
    if ! is_process_running "$FRONTEND_PID_FILE"; then
        log_error "Frontend non riuscito ad avviarsi. Controllare $FRONTEND_LOG"
        return 1
    fi
    
    if curl -s "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
        log_success "Frontend avviato e raggiungibile"
        return 0
    else
        log_error "Frontend avviato ma non raggiungibile. Controllare $FRONTEND_LOG"
        return 1
    fi
}

start_application() {
    echo -e "\n=======================================\n   CRM System - Deploy (PostgreSQL)\n======================================="
    log_info "Inizio deploy CRM System..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
        log_error "Database non in esecuzione. Eseguire prima ./prerequisites.sh"
        return 1
    fi
    
    check_and_free_ports
    
    if start_backend; then
        if start_frontend; then
            log_success "Deploy completato con successo!"
            show_status
        else
            log_error "Errore nell'avvio del frontend. Fermo il backend per sicurezza."
            stop_process "$BACKEND_PID_FILE" "Backend"
            return 1
        fi
    else
        log_error "Errore nell'avvio del backend."
        return 1
    fi
}

stop_application() {
    echo -e "\n=======================================\n   CRM System - Stop\n======================================="
    stop_process "$BACKEND_PID_FILE" "Backend"
    stop_process "$FRONTEND_PID_FILE" "Frontend"
    check_and_free_ports
    log_success "Applicazione fermata"
}

# --- LOGICA PRINCIPALE ---
case "${1:-start}" in
    "start")
        start_application
        ;;
    "stop")
        stop_application
        ;;
    "restart")
        stop_application
        sleep 2
        start_application
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac