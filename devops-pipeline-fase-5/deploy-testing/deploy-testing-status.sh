#!/bin/bash

# =======================================
#   Deploy Testing - Status Check
#   FASE 5: Status Step
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[STATUS]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[STATUS]${NC} ❌ $1"
}

# Testing configuration
TEST_DATABASE="$HOME/devops/CRM-System/testing/test.sqlite"
TEST_PORT_FRONTEND=3100
TEST_PORT_BACKEND=3101

log_info "Verifica status testing services..."

echo "=== TESTING SERVICES STATUS ==="

# Check backend
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" >/dev/null; then
    log_success "Backend testing: RUNNING (porta $TEST_PORT_BACKEND)"
else
    log_error "Backend testing: NOT RUNNING"
fi

# Check frontend
if curl -s "http://localhost:$TEST_PORT_FRONTEND" >/dev/null; then
    log_success "Frontend testing: RUNNING (porta $TEST_PORT_FRONTEND)"
else
    log_error "Frontend testing: NOT RUNNING"
fi

# Check testing tools
echo "\n=== TESTING TOOLS STATUS ==="
command -v jest >/dev/null 2>&1 && log_success "Jest: AVAILABLE" || log_error "Jest: NOT AVAILABLE"
command -v playwright >/dev/null 2>&1 && log_success "Playwright: AVAILABLE" || log_error "Playwright: NOT AVAILABLE"
command -v artillery >/dev/null 2>&1 && log_success "Artillery: AVAILABLE" || log_error "Artillery: NOT AVAILABLE"

# Check test database
echo "\n=== TEST DATABASE STATUS ==="
if [ -f "$TEST_DATABASE" ]; then
    local db_size=$(du -h "$TEST_DATABASE" | cut -f1)
    log_success "Test Database: AVAILABLE ($db_size)"
else
    log_error "Test Database: NOT FOUND"
fi