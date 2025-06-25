#!/bin/bash

# deploy.sh
# Script per compilare e avviare l'applicazione CRM System
# FASE 1: Validazione Base

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configurazione
PROJECT_DIR="$HOME/devops/CRM-System"
LOG_FILE="$HOME/deploy.log"
PID_FILE="$HOME/crm-pids.txt"
BACKEND_PORT=3001
FRONTEND_PORT=3000
HEALTH_CHECK_TIMEOUT=30
MAX_RETRIES=5

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

# Funzione per cleanup processi
cleanup() {
    print_status $YELLOW "Cleanup processi in corso..."
    
    if [ -f "$PID_FILE" ]; then
        while read -r pid; do
            if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                print_status $YELLOW "Terminazione processo PID: $pid"
                kill -TERM "$pid" 2>/dev/null || true
                sleep 2
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Cleanup porte specifiche
    for port in $BACKEND_PORT $FRONTEND_PORT; do
        local pid=$(lsof -ti:$port 2>/dev/null || true)
        if [ ! -z "$pid" ]; then
            print_status $YELLOW "Liberazione porta $port (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
}

# Funzione per verificare porta libera
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Porta occupata
    else
        return 0  # Porta libera
    fi
}

# Funzione per aspettare che una porta sia libera
wait_for_port_free() {
    local port=$1
    local timeout=$2
    local count=0
    
    while ! check_port $port && [ $count -lt $timeout ]; do
        sleep 1
        ((count++))
    done
    
    if [ $count -ge $timeout ]; then
        print_error "Timeout: porta $port ancora occupata dopo ${timeout}s"
        return 1
    fi
    
    return 0
}

# Funzione per verificare che un servizio sia attivo
wait_for_service() {
    local url=$1
    local timeout=$2
    local count=0
    
    print_status $BLUE "Attesa servizio: $url"
    
    while [ $count -lt $timeout ]; do
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            print_success "Servizio $url attivo"
            return 0
        fi
        sleep 2
        ((count += 2))
        echo -n "."
    done
    
    echo ""
    print_error "Timeout: servizio $url non raggiungibile dopo ${timeout}s"
    return 1
}

# Funzione per installare dipendenze
install_dependencies() {
    local dir=$1
    local name=$2
    
    print_status $BLUE "Installazione dipendenze $name..."
    
    cd "$dir"
    
    # Verifica se package.json esiste
    if [ ! -f "package.json" ]; then
        print_error "package.json non trovato in $dir"
        return 1
    fi
    
    # Cache npm per velocizzare
    npm config set audit-level moderate
    
    # Installazione con retry
    local retry=0
    while [ $retry -lt $MAX_RETRIES ]; do
        if npm install --no-audit --no-fund; then
            print_success "Dipendenze $name installate"
            return 0
        else
            ((retry++))
            print_warning "Tentativo $retry/$MAX_RETRIES fallito per $name"
            if [ $retry -lt $MAX_RETRIES ]; then
                sleep 5
                npm cache clean --force
            fi
        fi
    done
    
    print_error "Impossibile installare dipendenze $name dopo $MAX_RETRIES tentativi"
    return 1
}

# Funzione per build
build_component() {
    local dir=$1
    local name=$2
    
    print_status $BLUE "Build $name..."
    
    cd "$dir"
    
    if npm run build; then
        print_success "Build $name completata"
        return 0
    else
        print_error "Build $name fallita"
        return 1
    fi
}

# Funzione per avviare backend
start_backend() {
    print_status $BLUE "Avvio backend..."
    
    cd "$PROJECT_DIR/backend"
    
    # Verifica che il build sia presente
    if [ ! -d "dist" ] && [ ! -f "dist/app.js" ]; then
        print_warning "Build backend non trovato, avvio in modalità development"
        nohup npm run dev > "$HOME/backend.log" 2>&1 &
    else
        nohup npm start > "$HOME/backend.log" 2>&1 &
    fi
    
    local backend_pid=$!
    echo $backend_pid >> "$PID_FILE"
    
    print_status $GREEN "Backend avviato (PID: $backend_pid)"
    
    # Wait for backend to be ready
    if wait_for_service "http://localhost:$BACKEND_PORT/api/health" $HEALTH_CHECK_TIMEOUT; then
        print_success "Backend ready e health check OK"
        return 0
    else
        print_error "Backend non ready entro $HEALTH_CHECK_TIMEOUT secondi"
        return 1
    fi
}

# Funzione per avviare frontend
start_frontend() {
    print_status $BLUE "Avvio frontend..."
    
    cd "$PROJECT_DIR/frontend"
    
    # Verifica che il build sia presente
    if [ ! -d "dist" ]; then
        print_warning "Build frontend non trovato, avvio in modalità development"
        nohup npm run dev -- --host 0.0.0.0 --port $FRONTEND_PORT > "$HOME/frontend.log" 2>&1 &
    else
        nohup npm run preview -- --host 0.0.0.0 --port $FRONTEND_PORT > "$HOME/frontend.log" 2>&1 &
    fi
    
    local frontend_pid=$!
    echo $frontend_pid >> "$PID_FILE"
    
    print_status $GREEN "Frontend avviato (PID: $frontend_pid)"
    
    # Wait for frontend to be ready
    if wait_for_service "http://localhost:$FRONTEND_PORT" $HEALTH_CHECK_TIMEOUT; then
        print_success "Frontend ready"
        return 0
    else
        print_error "Frontend non ready entro $HEALTH_CHECK_TIMEOUT secondi"
        return 1
    fi
}

# Funzione per mostrare status
show_status() {
    echo -e "${GREEN}"
    echo "======================================="
    echo "   CRM SYSTEM - STATUS"
    echo "======================================="
    echo -e "${NC}"
    
    # Backend status
    if curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend:${NC} http://localhost:$BACKEND_PORT (RUNNING)"
        echo -e "${GREEN}✓ API Docs:${NC} http://localhost:$BACKEND_PORT/api/docs"
    else
        echo -e "${RED}✗ Backend:${NC} http://localhost:$BACKEND_PORT (NOT RESPONDING)"
    fi
    
    # Frontend status
    if curl -s "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend:${NC} http://localhost:$FRONTEND_PORT (RUNNING)"
    else
        echo -e "${RED}✗ Frontend:${NC} http://localhost:$FRONTEND_PORT (NOT RESPONDING)"
    fi
    
    echo ""
    echo "Credenziali di test:"
    echo "Email: admin@crm.local"
    echo "Password: admin123"
    echo ""
    echo "Log files:"
    echo "- Deploy: $LOG_FILE"
    echo "- Backend: $HOME/backend.log"
    echo "- Frontend: $HOME/frontend.log"
    echo ""
    
    if [ -f "$PID_FILE" ]; then
        echo "PIDs attivi:"
        cat "$PID_FILE"
        echo ""
    fi
    
    echo "Per fermare l'applicazione: ./deploy.sh stop"
}

# Funzione per fermare l'applicazione
stop_application() {
    print_status $BLUE "Arresto CRM System..."
    cleanup
    print_success "CRM System arrestato"
}

# Trap per cleanup automatico
trap cleanup EXIT INT TERM

# Banner
echo -e "${BLUE}"
echo "======================================="
echo "   CRM System - Deploy Script"
echo "   FASE 1: Validazione Base"
echo "======================================="
echo -e "${NC}"

# Gestione parametri
case "${1:-start}" in
    "stop")
        stop_application
        exit 0
        ;;
    "status")
        show_status
        exit 0
        ;;
    "restart")
        stop_application
        sleep 3
        ;;
    "start"|"")
        # Continua con il deploy
        ;;
    *)
        echo "Uso: $0 [start|stop|restart|status]"
        exit 1
        ;;
esac

# Verifica prerequisiti
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Directory progetto non trovata: $PROJECT_DIR"
    print_status $YELLOW "Eseguire prima: ./sync-devops-config.sh"
    exit 1
fi

# Verifica Node.js e npm
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    print_error "Node.js o npm non trovati. Eseguire prima: ./prerequisites.sh"
    exit 1
fi

print_status $BLUE "Inizio deploy CRM System..."

# Cleanup processi precedenti
cleanup

# Attendi che le porte si liberino
for port in $BACKEND_PORT $FRONTEND_PORT; do
    if ! wait_for_port_free $port 10; then
        print_error "Impossibile liberare porta $port"
        exit 1
    fi
done

# Installazione dipendenze root
print_status $BLUE "Installazione dipendenze root..."
cd "$PROJECT_DIR"
if ! npm install --no-audit --no-fund; then
    print_warning "Installazione dipendenze root fallita, continuo comunque..."
fi

# Installazione dipendenze backend
if ! install_dependencies "$PROJECT_DIR/backend" "backend"; then
    print_error "Installazione dipendenze backend fallita"
    exit 1
fi

# Installazione dipendenze frontend
if ! install_dependencies "$PROJECT_DIR/frontend" "frontend"; then
    print_error "Installazione dipendenze frontend fallita"
    exit 1
fi

# Build backend
if ! build_component "$PROJECT_DIR/backend" "backend"; then
    print_warning "Build backend fallita, provo in modalità development"
fi

# Build frontend
if ! build_component "$PROJECT_DIR/frontend" "frontend"; then
    print_warning "Build frontend fallita, provo in modalità development"
fi

# Avvio servizi
if ! start_backend; then
    print_error "Avvio backend fallito"
    cleanup
    exit 1
fi

if ! start_frontend; then
    print_error "Avvio frontend fallito"
    cleanup
    exit 1
fi

# Verifica finale
sleep 5
show_status

print_success "Deploy completato con successo!"
log "Deploy completed successfully"

echo ""
echo "L'applicazione è ora disponibile:"
echo "Frontend: http://localhost:$FRONTEND_PORT"
echo "Backend API: http://localhost:$BACKEND_PORT/api"
echo ""
echo "Per testare l'applicazione: ./test.sh"
echo "Per fermare l'applicazione: ./deploy.sh stop"
echo ""

# Non uscire per mantenere i processi attivi in background
# L'utente può usare Ctrl+C per interrompere
echo "Premi Ctrl+C per fermare l'applicazione..."
echo "Oppure esegui: ./deploy.sh stop"

# Trap rimuove il cleanup automatico all'uscita normale
trap - EXIT

# Wait indefinitely
while true; do
    sleep 60
    # Health check periodico
    if ! curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
        print_warning "Backend health check fallito"
    fi
done