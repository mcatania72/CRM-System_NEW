#!/bin/bash

# Backend Debug and Restart Script
# Diagnosi e risoluzione problemi backend

set -e

BACKEND_DIR="$HOME/devops/CRM-System/backend"
LOG_FILE="$HOME/backend-debug.log"

# Colori
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

echo "======================================="
echo "   Backend Debug & Fix Script"
echo "======================================="

log_info "Inizio diagnosi backend..."

# Verifica directory
if [[ ! -d "$BACKEND_DIR" ]]; then
    log_error "Directory backend non trovata: $BACKEND_DIR"
    exit 1
fi

cd "$BACKEND_DIR"

# 1. Verifica Node.js e npm
log_info "Verifica versioni..."
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"

# 2. Pulisci e reinstalla dipendenze
log_info "Pulizia e reinstallazione dipendenze..."
rm -rf node_modules package-lock.json dist
npm cache clean --force
npm install

# 3. Verifica dipendenze critiche
log_info "Verifica dipendenze critiche..."
npm list express typeorm sqlite3 ts-node typescript 2>/dev/null || log_warning "Alcune dipendenze mancanti"

# 4. Installa dipendenze globali se necessarie
if ! command -v ts-node &> /dev/null; then
    log_info "Installazione ts-node globale..."
    npm install -g ts-node typescript || log_warning "Impossibile installare ts-node globale"
fi

# 5. Test TypeScript compilation
log_info "Test compilazione TypeScript..."
if npx tsc --noEmit; then
    log_success "TypeScript check OK"
else
    log_error "Errori TypeScript trovati"
    npx tsc --noEmit 2>&1 | head -10
fi

# 6. Test build
log_info "Tentativo build..."
if npm run build > build.log 2>&1; then
    log_success "Build completata con successo"
    
    # Test avvio da build
    log_info "Test avvio da build..."
    timeout 10s npm start > start.log 2>&1 &
    CHILD_PID=$!
    sleep 5
    
    if ps -p $CHILD_PID > /dev/null 2>&1; then
        log_success "Backend avviato da build (PID: $CHILD_PID)"
        kill $CHILD_PID 2>/dev/null || true
    else
        log_warning "Backend build non si avvia correttamente"
        cat start.log | head -10
    fi
else
    log_warning "Build fallita, controllo errori..."
    cat build.log | head -10
fi

# 7. Test dev mode
log_info "Test dev mode..."
if timeout 10s npm run dev > dev.log 2>&1 &
then
    DEV_PID=$!
    sleep 5
    
    if ps -p $DEV_PID > /dev/null 2>&1; then
        log_success "Backend funziona in dev mode (PID: $DEV_PID)"
        
        # Test health check
        sleep 2
        if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
            log_success "Health check OK"
        else
            log_warning "Health check fallito"
        fi
        
        kill $DEV_PID 2>/dev/null || true
    else
        log_error "Dev mode fallito"
        cat dev.log | head -10
    fi
else
    log_error "Impossibile avviare dev mode"
fi

# 8. Verifica database
log_info "Verifica database..."
if [[ -f "database.sqlite" ]]; then
    echo "Database esiste: $(ls -lh database.sqlite)"
    if command -v sqlite3 &> /dev/null; then
        sqlite3 database.sqlite "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || log_warning "Errore lettura database"
    fi
else
    echo "Database non esiste, sarà creato al primo avvio"
fi

# 9. Verifica porte
log_info "Verifica porte..."
if lsof -ti:3001 >/dev/null 2>&1; then
    log_warning "Porta 3001 già occupata"
    lsof -ti:3001 | xargs -r ps -p
else
    log_success "Porta 3001 libera"
fi

# 10. Fix permissions
log_info "Fix permessi..."
chmod -R 755 src/
chown -R $USER:$USER . 2>/dev/null || true

echo ""
echo "======================================="
echo "   RIEPILOGO DIAGNOSI"
echo "======================================="
echo "Log completo: $LOG_FILE"
echo "Build log: $BACKEND_DIR/build.log"
echo "Dev log: $BACKEND_DIR/dev.log"
echo "Start log: $BACKEND_DIR/start.log"
echo ""
echo "Prova ora a riavviare:"
echo "  cd ~/devops-pipeline-fase-1"
echo "  ./deploy.sh restart"
echo ""

log_success "Diagnosi completata"