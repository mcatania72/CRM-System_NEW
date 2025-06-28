#!/bin/bash

# ============================================
# Deploy Testing - Smoke Tests Module
# FASE 5: Test di verifica rapida
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_smoke() {
    echo -e "${BLUE}[SMOKE]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SMOKE: $1" >> ~/deploy-testing.log
}

log_smoke "Esecuzione smoke tests..."

# Test backend health
log_smoke "Test backend health (3101)..."
if curl -s --max-time 10 http://localhost:3101/api/health >/dev/null 2>&1; then
    log_smoke "✅ Backend health OK"
else
    log_smoke "❌ Backend health FAIL"
    exit 1
fi

# Test frontend response (FIXED: porta 3000 invece di 3100)
log_smoke "Test frontend response (3000)..."
if curl -s --max-time 10 http://localhost:3000 >/dev/null 2>&1; then
    log_smoke "✅ Frontend response OK"
else
    log_smoke "❌ Frontend response FAIL"
    exit 1
fi

# Test backend API endpoint
log_smoke "Test backend API..."
RESPONSE=$(curl -s --max-time 10 http://localhost:3101/api/auth/status 2>/dev/null)
if [[ $? -eq 0 ]]; then
    log_smoke "✅ Backend API OK"
else
    log_smoke "⚠️ Backend API response warning (continuando...)"
fi

# Test database connectivity
log_smoke "Test database connectivity..."
if [[ -f "$HOME/testing-workspace/test.db" ]]; then
    log_smoke "✅ Test database presente"
else
    log_smoke "⚠️ Test database non trovato"
fi

# Test port availability (FIXED: verifica porta 3000 invece di 3100)
log_smoke "Verifica porte testing..."
if netstat -ln | grep -q ":3101.*LISTEN"; then
    log_smoke "✅ Porta 3101 in ascolto"
else
    log_smoke "❌ Porta 3101 non in ascolto"
    exit 1
fi

if netstat -ln | grep -q ":3000.*LISTEN"; then
    log_smoke "✅ Porta 3000 in ascolto"
else
    log_smoke "❌ Porta 3000 non in ascolto"
    exit 1
fi

log_smoke "✅ Smoke tests completati con successo!"
exit 0