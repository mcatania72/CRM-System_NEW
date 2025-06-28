#!/bin/bash

# ============================================
# Deploy Testing - Status Check Module
# FASE 5: Verifica status servizi
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

log_status "Verifica status servizi testing..."

# Check backend process
if [[ -f "$HOME/backend-testing.pid" ]]; then
    BACKEND_PID=$(cat "$HOME/backend-testing.pid")
    if ps -p $BACKEND_PID > /dev/null 2>&1; then
        log_status "✅ Backend testing in esecuzione (PID: $BACKEND_PID)"
    else
        log_status "❌ Backend testing non in esecuzione"
    fi
else
    log_status "❌ Backend testing PID file non trovato"
fi

# Check frontend process
if [[ -f "$HOME/frontend-testing.pid" ]]; then
    FRONTEND_PID=$(cat "$HOME/frontend-testing.pid")
    if ps -p $FRONTEND_PID > /dev/null 2>&1; then
        log_status "✅ Frontend testing in esecuzione (PID: $FRONTEND_PID)"
    else
        log_status "❌ Frontend testing non in esecuzione"
    fi
else
    log_status "❌ Frontend testing PID file non trovato"
fi

# Check ports
log_status "Verifica porte:"
if netstat -ln 2>/dev/null | grep -q ":3101.*LISTEN"; then
    log_status "  - Porta 3101: ✅ ATTIVA"
else
    log_status "  - Porta 3101: ❌ INATTIVA"
fi

if netstat -ln 2>/dev/null | grep -q ":3100.*LISTEN"; then
    log_status "  - Porta 3100: ✅ ATTIVA"
else
    log_status "  - Porta 3100: ❌ INATTIVA"
fi

# Check services health
log_status "Verifica health servizi:"
if curl -s --max-time 5 http://localhost:3101/api/health >/dev/null 2>&1; then
    log_status "  - Backend: ✅ HEALTHY"
else
    log_status "  - Backend: ❌ UNHEALTHY"
fi

if curl -s --max-time 5 http://localhost:3100 >/dev/null 2>&1; then
    log_status "  - Frontend: ✅ HEALTHY"
else
    log_status "  - Frontend: ❌ UNHEALTHY"
fi

# Check testing workspace
log_status "Verifica testing workspace:"
if [[ -d "$HOME/testing-workspace" ]]; then
    log_status "  - Workspace: ✅ PRESENTE"
    
    if [[ -f "$HOME/testing-workspace/.env.testing" ]]; then
        log_status "  - Config: ✅ PRESENTE"
    else
        log_status "  - Config: ❌ MANCANTE"
    fi
    
    if [[ -f "$HOME/testing-workspace/test.db" ]]; then
        log_status "  - Test DB: ✅ PRESENTE"
    else
        log_status "  - Test DB: ❌ MANCANTE"
    fi
else
    log_status "  - Workspace: ❌ MANCANTE"
fi

# Check log files
log_status "Log files:"
for log_file in "backend-testing.log" "frontend-testing.log" "deploy-testing.log"; do
    if [[ -f "$HOME/$log_file" ]]; then
        size=$(du -h "$HOME/$log_file" | cut -f1)
        log_status "  - $log_file: ✅ ($size)"
    else
        log_status "  - $log_file: ❌ MANCANTE"
    fi
done

log_status "Status check completato"
exit 0