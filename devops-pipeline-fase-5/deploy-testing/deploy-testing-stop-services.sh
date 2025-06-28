#!/bin/bash

# ============================================
# Deploy Testing - Stop Services Module
# FASE 5: Stop servizi testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_stop() {
    echo -e "${BLUE}[STOP]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') STOP: $1" >> ~/deploy-testing.log
}

log_stop "Arresto servizi testing..."

# Stop backend testing
if [[ -f "$HOME/backend-testing.pid" ]]; then
    BACKEND_PID=$(cat "$HOME/backend-testing.pid")
    if ps -p $BACKEND_PID > /dev/null 2>&1; then
        kill $BACKEND_PID
        log_stop "✅ Backend testing arrestato (PID: $BACKEND_PID)"
    else
        log_stop "⚠️ Backend testing già arrestato"
    fi
    rm -f "$HOME/backend-testing.pid"
fi

# Stop frontend testing
if [[ -f "$HOME/frontend-testing.pid" ]]; then
    FRONTEND_PID=$(cat "$HOME/frontend-testing.pid")
    if ps -p $FRONTEND_PID > /dev/null 2>&1; then
        kill $FRONTEND_PID
        log_stop "✅ Frontend testing arrestato (PID: $FRONTEND_PID)"
    else
        log_stop "⚠️ Frontend testing già arrestato"
    fi
    rm -f "$HOME/frontend-testing.pid"
fi

# Kill any remaining testing processes
pkill -f "node.*3101" 2>/dev/null && log_stop "✅ Processi Node 3101 terminati"
pkill -f "vite.*3100" 2>/dev/null && log_stop "✅ Processi Vite 3100 terminati"
pkill -f "npm.*test" 2>/dev/null && log_stop "✅ Processi NPM test terminati"

# Wait for processes to terminate
sleep 2

# Force kill if still running
if netstat -ln 2>/dev/null | grep -q ":3101.*LISTEN"; then
    fuser -k 3101/tcp 2>/dev/null && log_stop "✅ Porta 3101 liberata forzatamente"
fi

if netstat -ln 2>/dev/null | grep -q ":3100.*LISTEN"; then
    fuser -k 3100/tcp 2>/dev/null && log_stop "✅ Porta 3100 liberata forzatamente"
fi

log_stop "✅ Servizi testing arrestati con successo!"
exit 0