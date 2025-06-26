#!/bin/bash

# CRM System Deploy Script
# FASE 1: Validazione Base

set -e

# Configurazioni
BACKEND_DIR="$HOME/devops/CRM-System/backend"
FRONTEND_DIR="$HOME/devops/CRM-System/frontend"
LOG_FILE="$HOME/deploy.log"
BACKEND_LOG="$HOME/backend.log"
FRONTEND_LOG="$HOME/frontend.log"
BACKEND_PID_FILE="$HOME/backend.pid"
FRONTEND_PID_FILE="$HOME/frontend.pid"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Funzione per rilevare modalità backend
detect_backend_mode() {
    local pid=$1
    
    # Controlla se è ts-node (sviluppo)
    if ps -p "$pid" -o cmd --no-headers | grep -q "ts-node"; then
        echo "SVILUPPO (ts-node)"
        return 0
    fi
    
    # Controlla se è npm run dev
    if ps -p "$pid" -o cmd --no-headers | grep -q "npm.*dev"; then
        echo "SVILUPPO (npm dev)"
        return 0
    fi
    
    # Controlla nel log per capire come è stato avviato
    if tail -50 "$BACKEND_LOG" 2>/dev/null | grep -q "> crm-backend.*dev"; then
        echo "SVILUPPO (npm run dev)"
        return 0
    elif tail -50 "$BACKEND_LOG" 2>/dev/null | grep -q "> crm-backend.*start"; then
        echo "PRODUZIONE (npm start)"
        return 0
    fi
    
    # Controlla se è node con file .js (produzione)
    if ps -p "$pid" -o cmd --no-headers | grep -q "node.*dist\|node.*\.js"; then
        echo "PRODUZIONE (node)"
        return 0
    fi
    
    # Default
    echo "SCONOSCIUTO"
}

# Funzione per rilevare modalità frontend
detect_frontend_mode() {
    local pid=$1
    
    # Controlla se è vite dev
    if ps -p "$pid" -o cmd --no-headers | grep -q "vite.*dev\|node.*vite[^/]*$"; then
        echo "SVILUPPO (vite dev)"
        return 0
    fi
    
    # Controlla nel log
    if tail -50 "$FRONTEND_LOG" 2>/dev/null | grep -q "> crm-frontend.*dev"; then
        echo "SVILUPPO (npm run dev)"
        return 0
    elif tail -50 "$FRONTEND_LOG" 2>/dev/null | grep -q "> crm-frontend.*preview"; then
        echo "PRODUZIONE (npm run preview)"
        return 0
    fi
    
    # Controlla se è vite preview
    if ps -p "$pid" -o cmd --no-headers | grep -q "vite.*preview"; then
        echo "PRODUZIONE (vite preview)"
        return 0
    fi
    
    # Default per vite generico
    if ps -p "$pid" -o cmd --no-headers | grep -q "vite"; then
        echo "SVILUPPO (vite)"
        return 0
    fi
    
    echo "SCONOSCIUTO"
}

# Funzione per verificare se un processo è in esecuzione
is_process_running() {
    local pid_file=$1
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Funzione per fermare un processo
stop_process() {
    local pid_file=$1
    local service_name=$2
    
    if is_process_running "$pid_file"; then
        local pid=$(cat "$pid_file")
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

# Funzione per verificare e liberare porte
check_and_free_ports() {
    log_info "Verifico porte 3000 e 3001..."
    
    # Porta 3000
    if lsof -ti:3000 >/dev/null 2>&1; then
        log_warning "Porta 3000 occupata, libero..."
        lsof -ti:3000 | xargs -r kill -9
    fi
    
    # Porta 3001
    if lsof -ti:3001 >/dev/null 2>&1; then
        log_warning "Porta 3001 occupata, libero..."
        lsof -ti:3001 | xargs -r kill -9
    fi
    
    sleep 2
}

# Funzione per mostrare lo status (SENZA FERMARE L'APP)
show_status() {
    echo ""
    echo "======================================="
    echo "   CRM System - Status Check"
    echo "======================================="
    
    # Status Backend
    if is_process_running "$BACKEND_PID_FILE"; then
        local backend_pid=$(cat "$BACKEND_PID_FILE")
        local backend_mode=$(detect_backend_mode "$backend_pid")
        
        log_success "Backend in esecuzione (PID: $backend_pid)"
        echo -e "${CYAN}  → Modalità: $backend_mode${NC}"
        
        # Test health check
        if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
            log_success "Backend risponde correttamente"
        else
            log_warning "Backend non risponde al health check"
        fi
    else
        log_error "Backend non in esecuzione"
    fi
    
    echo ""
    
    # Status Frontend
    if is_process_running "$FRONTEND_PID_FILE"; then
        local frontend_pid=$(cat "$FRONTEND_PID_FILE")
        local frontend_mode=$(detect_frontend_mode "$frontend_pid")
        
        log_success "Frontend in esecuzione (PID: $frontend_pid)"
        echo -e "${CYAN}  → Modalità: $frontend_mode${NC}"
        
        # Test frontend
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            log_success "Frontend risponde correttamente"
        else
            log_warning "Frontend non risponde"
        fi
    else
        log_error "Frontend non in esecuzione"
    fi
    
    # Verifica porte
    echo ""
    log_info "Verifica porte:"
    if lsof -ti:3001 >/dev/null 2>&1; then
        echo "  - Porta 3001: OCCUPATA"
    else
        echo "  - Porta 3001: LIBERA"
    fi
    
    if lsof -ti:3000 >/dev/null 2>&1; then
        echo "  - Porta 3000: OCCUPATA"
    else
        echo "  - Porta 3000: LIBERA"
    fi
    
    # Informazioni utili
    echo ""
    log_info "Accesso applicazione:"
    echo "  - Frontend: http://localhost:3000"
    echo "  - Backend API: http://localhost:3001/api"
    echo "  - Health Check: http://localhost:3001/api/health"
    
    echo ""
    log_info "Log files:"
    echo "  - Deploy: $LOG_FILE"
    echo "  - Backend: $BACKEND_LOG"
    echo "  - Frontend: $FRONTEND_LOG"
    
    echo ""
    echo "Credenziali di accesso:"
    echo "  Email: admin@crm.local"
    echo "  Password: admin123"
    echo ""
}

# Funzione per fermare l'applicazione
stop_application() {
    echo ""
    echo "======================================="
    echo "   CRM System - Stop"
    echo "======================================="
    
    stop_process "$BACKEND_PID_FILE" "Backend"
    stop_process "$FRONTEND_PID_FILE" "Frontend"
    check_and_free_ports
    
    log_success "Applicazione fermata"
}

# Funzione per avviare il backend
start_backend() {
    log_info "Avvio backend..."
    
    if [[ ! -d "$BACKEND_DIR" ]]; then
        log_error "Directory backend non trovata: $BACKEND_DIR"
        return 1
    fi
    
    cd "$BACKEND_DIR"
    
    # Installa dipendenze se necessario
    if [[ ! -d "node_modules" ]]; then
        log_info "Installazione dipendenze backend..."
        npm install
    fi
    
    # Prova build
    log_info "Build backend..."
    if npm run build > "$BACKEND_LOG" 2>&1; then
        log_success "Build backend completata"
        log_info "Avvio backend in modalità PRODUZIONE..."
        # Avvia da build
        nohup npm start > "$BACKEND_LOG" 2>&1 &
    else
        log_warning "Build backend fallita, provo in modalità SVILUPPO..."
        log_info "Avvio backend in modalità SVILUPPO (ts-node)..."
        # Avvia in dev mode
        nohup npm run dev > "$BACKEND_LOG" 2>&1 &
    fi
    
    local backend_pid=$!
    echo $backend_pid > "$BACKEND_PID_FILE"
    
    # Verifica avvio
    sleep 5
    if is_process_running "$BACKEND_PID_FILE"; then
        local backend_mode=$(detect_backend_mode "$backend_pid")
        log_success "Backend avviato (PID: $backend_pid) - $backend_mode"
        
        # Test health check con retry
        local retries=0
        while [[ $retries -lt 10 ]]; do
            if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
                log_success "Backend health check OK"
                return 0
            fi
            sleep 2
            ((retries++))
        done
        
        log_warning "Backend avviato ma health check fallito"
    else
        log_error "Backend non riuscito ad avviarsi"
        return 1
    fi
}

# Funzione per avviare il frontend
start_frontend() {
    log_info "Avvio frontend..."
    
    if [[ ! -d "$FRONTEND_DIR" ]]; then
        log_error "Directory frontend non trovata: $FRONTEND_DIR"
        return 1
    fi
    
    cd "$FRONTEND_DIR"
    
    # Installa dipendenze se necessario
    if [[ ! -d "node_modules" ]]; then
        log_info "Installazione dipendenze frontend..."
        npm install
    fi
    
    # Prova build
    log_info "Build frontend..."
    if npm run build > "$FRONTEND_LOG" 2>&1; then
        log_success "Build frontend completata"
        log_info "Avvio frontend in modalità PRODUZIONE..."
        # Avvia preview
        nohup npm run preview > "$FRONTEND_LOG" 2>&1 &
    else
        log_warning "Build frontend fallita, provo in modalità SVILUPPO..."
        log_info "Avvio frontend in modalità SVILUPPO (vite dev)..."
        # Avvia in dev mode
        nohup npm run dev > "$FRONTEND_LOG" 2>&1 &
    fi
    
    local frontend_pid=$!
    echo $frontend_pid > "$FRONTEND_PID_FILE"
    
    # Verifica avvio
    sleep 5
    if is_process_running "$FRONTEND_PID_FILE"; then
        local frontend_mode=$(detect_frontend_mode "$frontend_pid")
        log_success "Frontend avviato (PID: $frontend_pid) - $frontend_mode"
        
        # Test frontend con retry
        local retries=0
        while [[ $retries -lt 10 ]]; do
            if curl -s http://localhost:3000 >/dev/null 2>&1; then
                log_success "Frontend raggiungibile"
                return 0
            fi
            sleep 2
            ((retries++))
        done
        
        log_warning "Frontend avviato ma non raggiungibile"
    else
        log_error "Frontend non riuscito ad avviarsi"
        return 1
    fi
}

# Funzione per avviare l'applicazione
start_application() {
    echo ""
    echo "======================================="
    echo "   CRM System - Deploy Script"
    echo "   FASE 1: Validazione Base"
    echo "======================================="
    
    log_info "Inizio deploy CRM System..."
    
    # Verifica che il repository sia stato clonato
    if [[ ! -d "$HOME/devops/CRM-System" ]]; then
        log_info "Clone del repository CRM-System..."
        mkdir -p "$HOME/devops"
        cd "$HOME/devops"
        git clone https://github.com/mcatania72/CRM-System.git
        log_success "Repository clonato con successo"
    fi
    
    check_and_free_ports
    
    # Avvia backend
    if start_backend; then
        # Avvia frontend
        if start_frontend; then
            echo ""
            log_success "Deploy completato con successo!"
            echo ""
            echo "L'applicazione è ora disponibile:"
            echo "  Frontend: http://localhost:3000"
            echo "  Backend API: http://localhost:3001/api"
            echo ""
            echo "Credenziali di accesso:"
            echo "  Email: admin@crm.local"
            echo "  Password: admin123"
            echo ""
            echo "Per verificare lo status e le modalità operative:"
            echo "  ./deploy.sh status"
            echo ""
        else
            log_error "Errore nell'avvio del frontend"
            return 1
        fi
    else
        log_error "Errore nell'avvio del backend"
        return 1
    fi
}

# Main script logic
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
        echo ""
        echo "Comandi disponibili:"
        echo "  start   - Avvia l'applicazione CRM"
        echo "  stop    - Ferma l'applicazione CRM" 
        echo "  restart - Riavvia l'applicazione CRM"
        echo "  status  - Mostra status completo con modalità operative"
        echo ""
        exit 1
        ;;
esac