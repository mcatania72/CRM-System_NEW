#!/bin/bash

# Test E2E Semplificati - FASE 5 Enterprise Testing
# Script ottimizzato per test veloci senza dipendenze complesse

echo "==============================================="
echo "🧪 SIMPLE E2E TESTS - FASE 5"
echo "==============================================="

# Directory di lavoro
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configurazione
FRONTEND_URL="http://localhost:3000"
BACKEND_URL="http://localhost:8000"
TIMEOUT=30

# Funzioni di utility
check_service() {
    local url=$1
    local name=$2
    echo "[E2E-SIMPLE] Verifica $name su $url..."
    
    if curl -s --max-time 5 "$url" > /dev/null 2>&1; then
        echo "✅ $name disponibile"
        return 0
    else
        echo "❌ $name non disponibile"
        return 1
    fi
}

# Test semplificati senza autenticazione complessa
simple_connectivity_test() {
    echo "[E2E-SIMPLE] Test connettività base..."
    
    # Test frontend
    if check_service "$FRONTEND_URL" "Frontend"; then
        echo "✅ Frontend connectivity OK"
    else
        echo "⚠️ Frontend non disponibile - continuando con altri test"
    fi
    
    # Test backend health
    if check_service "$BACKEND_URL/health" "Backend Health"; then
        echo "✅ Backend health OK"
    elif check_service "$BACKEND_URL" "Backend"; then
        echo "✅ Backend base OK"
    else
        echo "⚠️ Backend non disponibile - continuando con test offline"
    fi
}

# Test base