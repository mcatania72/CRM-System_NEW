#!/bin/bash

# =======================================
#   Test Advanced - Unit Tests Module
#   FASE 5: Unit Testing
# =======================================

# NO set -e per gestire meglio gli errori

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    echo -e "${BLUE}[UNIT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[UNIT]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[UNIT]${NC} ❌ $1"
}

log_test "Esecuzione Unit Tests..."

REPORTS_DIR="$HOME/devops/CRM-System/testing/reports"
mkdir -p "$REPORTS_DIR"

backend_passed=true
frontend_passed=true

# Backend unit tests
log_test "Unit tests backend..."
cd "$HOME/devops/CRM-System/backend"

if npm test -- --coverage --coverageReporters=json-summary --coverageReporters=html --coverageDirectory="$REPORTS_DIR/backend-coverage" > "$REPORTS_DIR/backend-unit-tests.log" 2>&1; then
    log_success "Backend unit tests: PASSED"
else
    log_error "Backend unit tests: FAILED"
    backend_passed=false
fi

# Frontend unit tests  
log_test "Unit tests frontend..."
cd "$HOME/devops/CRM-System/frontend"

if npm test -- --coverage --watchAll=false --coverageDirectory="$REPORTS_DIR/frontend-coverage" > "$REPORTS_DIR/frontend-unit-tests.log" 2>&1; then
    log_success "Frontend unit tests: PASSED"
else
    log_error "Frontend unit tests: FAILED"
    frontend_passed=false
fi

if $backend_passed && $frontend_passed; then
    log_success "Unit Tests: ALL PASSED 🎉"
    exit 0
else
    log_error "Unit Tests: SOME FAILED ❌"
    exit 1
fi