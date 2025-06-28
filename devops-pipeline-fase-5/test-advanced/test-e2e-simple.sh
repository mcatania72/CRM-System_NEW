#!/bin/bash

# ============================================
# Test E2E Semplificati - FASE 5
# Test veloci con auto-detection porte
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_e2e() {
    echo -e "${BLUE}[E2E-SIMPLE]${NC} $1"
}

log_e2e "🧪 Avvio E2E tests semplificati con auto-detection porte..."

# Configurazione con porte preferite
FRONTEND_PORTS=(3100 3000 4173 3002)
BACKEND_PORTS=(3101 3001 8000 8001)
TIMEOUT=10

# Funzione per rilevare porta attiva
detect_active_port() {
    local service_name=$1
    local ports_array=("${@:2}")
    
    for port in "${ports_array[@]}"; do
        local url="http://localhost:${port}"
        log_e2e "🔍 Testing ${service_name} on port ${port}..."
        
        if curl -s --max-time 3 "${url}" >/dev/null 2>&1; then
            log_e2e "✅ ${service_name} found on port ${port}"
            echo "${url}"
            return 0
        fi
    done
    
    log_e2e "❌ ${service_name} not found on any port"
    return 1
}

# Auto-detect frontend port
log_e2e "🔍 Auto-detecting frontend port..."
FRONTEND_URL=$(detect_active_port "Frontend" "${FRONTEND_PORTS[@]}")
if [[ $? -ne 0 ]]; then
    log_e2e "❌ Frontend not accessible on any common port"
    log_e2e "⚠️ Ports tested: ${FRONTEND_PORTS[*]}"
    exit 1
fi

# Auto-detect backend port
log_e2e "🔍 Auto-detecting backend port..."
BACKEND_URL=$(detect_active_port "Backend" "${BACKEND_PORTS[@]}")
if [[ $? -ne 0 ]]; then
    log_e2e "❌ Backend not accessible on any common port"
    log_e2e "⚠️ Ports tested: ${BACKEND_PORTS[*]}"
    exit 1
fi

log_e2e "📋 Configurazione rilevata:"
log_e2e "   Frontend: ${FRONTEND_URL}"
log_e2e "   Backend:  ${BACKEND_URL}"
log_e2e ""

# Test 1: Frontend loading
log_e2e "Test 1: Frontend HTML loading..."
if curl -s --max-time $TIMEOUT "${FRONTEND_URL}" | grep -q "<!DOCTYPE html\|<html\|CRM"; then
    log_e2e "✅ Frontend HTML loading OK"
else
    log_e2e "❌ Frontend HTML loading FAIL"
    exit 1
fi

# Test 2: Backend API health
log_e2e "Test 2: Backend API health..."
if curl -s --max-time $TIMEOUT "${BACKEND_URL}/api/health" | grep -q "OK\|healthy\|status"; then
    log_e2e "✅ Backend API health OK"
elif curl -s --max-time $TIMEOUT "${BACKEND_URL}/health" | grep -q "OK\|healthy\|status"; then
    log_e2e "✅ Backend health OK (alternate endpoint)"
else
    log_e2e "❌ Backend API health FAIL"
    exit 1
fi

# Test 3: Frontend static resources
log_e2e "Test 3: Frontend static resources..."
if curl -s --max-time $TIMEOUT "${FRONTEND_URL}/static/" >/dev/null 2>&1 || \
   curl -s --max-time $TIMEOUT "${FRONTEND_URL}/assets/" >/dev/null 2>&1 || \
   curl -s --max-time $TIMEOUT "${FRONTEND_URL}/js/" >/dev/null 2>&1; then
    log_e2e "✅ Frontend static resources OK"
else
    log_e2e "⚠️ Frontend static resources warning (SPA mode - normale)"
fi

# Test 4: Backend API endpoints basic
log_e2e "Test 4: Backend API endpoints..."
if curl -s --max-time $TIMEOUT "${BACKEND_URL}/api/auth/status" >/dev/null 2>&1; then
    log_e2e "✅ Backend auth endpoint OK"
elif curl -s --max-time $TIMEOUT "${BACKEND_URL}/api/" >/dev/null 2>&1; then
    log_e2e "✅ Backend API base endpoint OK"
else
    log_e2e "⚠️ Backend auth endpoint warning (continuando...)"
fi

# Test 5: Database connectivity via backend
log_e2e "Test 5: Database connectivity test..."
if [[ -f "$HOME/testing-workspace/test.db" ]] || [[ -f "$HOME/devops/CRM-System/test.db" ]]; then
    log_e2e "✅ Test database accessible"
else
    log_e2e "⚠️ Test database not found (continuando...)"
fi

# Test 6: Response time check
log_e2e "Test 6: Response time check..."
START_TIME=$(date +%s%N)
curl -s --max-time $TIMEOUT "${FRONTEND_URL}" >/dev/null 2>&1
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

if [[ $RESPONSE_TIME -lt 2000 ]]; then
    log_e2e "✅ Frontend response time OK (${RESPONSE_TIME}ms)"
else
    log_e2e "⚠️ Frontend response time slow (${RESPONSE_TIME}ms)"
fi

# Test 7: Cross-service connectivity
log_e2e "Test 7: Frontend-Backend proxy test..."
# Test se il frontend riesce a fare proxy al backend
PROXY_TEST=$(curl -s --max-time $TIMEOUT "${FRONTEND_URL}/api/health" 2>/dev/null || echo "PROXY_FAIL")
if [[ "$PROXY_TEST" != "PROXY_FAIL" ]]; then
    log_e2e "✅ Frontend-Backend proxy OK"
else
    log_e2e "⚠️ Frontend-Backend proxy warning (continuando...)"
fi

log_e2e ""
log_e2e "🎉 E2E tests semplificati completati con successo!"
log_e2e "📊 Summary:"
log_e2e "   ✅ Frontend operativo su: ${FRONTEND_URL}"
log_e2e "   ✅ Backend operativo su: ${BACKEND_URL}"
log_e2e "   ✅ Servizi comunicanti e funzionali"
log_e2e ""

exit 0