#!/bin/bash

# =======================================
#   Deploy Testing - Smoke Tests
#   FASE 5: Smoke Tests Step
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[SMOKE]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SMOKE]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[SMOKE]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[SMOKE]${NC} ⚠️ $1"
}

# Testing configuration
TEST_PORT_FRONTEND=3100
TEST_PORT_BACKEND=3101

log_info "Esecuzione smoke tests..."

tests_passed=0
tests_total=4

# Test 1: Backend health
log_info "Test 1: Backend health check"
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" | grep -q "ok"; then
    log_success "✓ Backend health check"
    ((tests_passed++))
else
    log_error "✗ Backend health check"
fi

# Test 2: Frontend accessibility
log_info "Test 2: Frontend accessibility"
if curl -s "http://localhost:$TEST_PORT_FRONTEND" >/dev/null; then
    log_success "✓ Frontend accessibility"
    ((tests_passed++))
else
    log_error "✗ Frontend accessibility"
fi

# Test 3: Database connection
log_info "Test 3: Database connection"
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/customers" >/dev/null; then
    log_success "✓ Database connection"
    ((tests_passed++))
else
    log_error "✗ Database connection"
fi

# Test 4: Testing tools
log_info "Test 4: Testing tools availability"
if command -v jest >/dev/null 2>&1 && command -v playwright >/dev/null 2>&1; then
    log_success "✓ Testing tools available"
    ((tests_passed++))
else
    log_error "✗ Testing tools missing"
fi

echo "\n=== SMOKE TESTS RESULTS ==="
echo "Tests passed: $tests_passed/$tests_total"

if [ $tests_passed -eq $tests_total ]; then
    log_success "Tutti i smoke tests passati! 🎉"
    exit 0
else
    log_warning "Alcuni smoke tests falliti"
    exit 1
fi