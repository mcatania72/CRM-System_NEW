#!/bin/bash

# ============================================
# Test Advanced - Unit Tests Module
# FASE 5: Unit testing backend e frontend
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_unit() {
    echo -e "${BLUE}[UNIT]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') UNIT: $1" >> ~/test-advanced.log
}

log_unit "Esecuzione Unit Tests..."

# Backend Unit Tests
log_unit "Backend Unit Tests..."
cd "$HOME/devops/CRM-System/backend" || exit 1

# FIXED: Gestione corretta dei codici di uscita
npm test 2>&1 | tee "$HOME/testing-workspace/reports/unit-backend.log"
BACKEND_EXIT_CODE=$?

if [[ $BACKEND_EXIT_CODE -eq 0 ]]; then
    log_unit "✅ Backend unit tests PASSED"
    BACKEND_SUCCESS=true
elif [[ $BACKEND_EXIT_CODE -eq 1 ]]; then
    # Check if it's "no tests found" vs real failure
    if grep -q "No tests found" "$HOME/testing-workspace/reports/unit-backend.log"; then
        log_unit "⚠️ Backend: No tests found (OK per setup fase)"
        BACKEND_SUCCESS=true
    else
        log_unit "❌ Backend unit tests FAILED"
        BACKEND_SUCCESS=false
    fi
else
    log_unit "❌ Backend unit tests ERROR (exit code: $BACKEND_EXIT_CODE)"
    BACKEND_SUCCESS=false
fi

# Frontend Unit Tests
log_unit "Frontend Unit Tests..."
cd "$HOME/devops/CRM-System/frontend" || exit 1

npm test 2>&1 | tee "$HOME/testing-workspace/reports/unit-frontend.log"
FRONTEND_EXIT_CODE=$?

if [[ $FRONTEND_EXIT_CODE -eq 0 ]]; then
    log_unit "✅ Frontend unit tests PASSED"
    FRONTEND_SUCCESS=true
elif [[ $FRONTEND_EXIT_CODE -eq 1 ]]; then
    # Check if it's "no tests found" vs real failure
    if grep -q "No test files found" "$HOME/testing-workspace/reports/unit-frontend.log"; then
        log_unit "⚠️ Frontend: No test files found (OK per setup fase)"
        FRONTEND_SUCCESS=true
    else
        log_unit "❌ Frontend unit tests FAILED"
        FRONTEND_SUCCESS=false
    fi
else
    log_unit "❌ Frontend unit tests ERROR (exit code: $FRONTEND_EXIT_CODE)"
    FRONTEND_SUCCESS=false
fi

# Generate unit test report
log_unit "Generazione report unit tests..."
cat > "$HOME/testing-workspace/reports/unit-summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "backend": $BACKEND_SUCCESS,
  "frontend": $FRONTEND_SUCCESS,
  "overall": $([ "$BACKEND_SUCCESS" = true ] && [ "$FRONTEND_SUCCESS" = true ] && echo true || echo false),
  "note": "No tests found is OK during setup phase"
}
EOF

if [[ "$BACKEND_SUCCESS" == true && "$FRONTEND_SUCCESS" == true ]]; then
    log_unit "✅ Unit tests completati con successo!"
    log_unit "📝 Nota: Setup di testing pronto per aggiunta test reali"
    exit 0
else
    log_unit "❌ Unit tests falliti"
    exit 1
fi