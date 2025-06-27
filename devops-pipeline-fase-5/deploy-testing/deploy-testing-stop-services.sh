#!/bin/bash

# =======================================
#   Deploy Testing - Stop Services
#   FASE 5: Stop Step
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[STOP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[STOP]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[STOP]${NC} ❌ $1"
}

# Testing configuration
TEST_PORT_FRONTEND=3100
TEST_PORT_BACKEND=3101

log_info "Fermata testing services..."

# Stop services using PID files
if [ -f "$HOME/backend-testing.pid" ]; then
    kill $(cat "$HOME/backend-testing.pid") 2>/dev/null || true
    rm "$HOME/backend-testing.pid"
    log_success "Backend testing fermato"
fi

if [ -f "$HOME/frontend-testing.pid" ]; then
    kill $(cat "$HOME/frontend-testing.pid") 2>/dev/null || true
    rm "$HOME/frontend-testing.pid"
    log_success "Frontend testing fermato"
fi

# Force kill any remaining processes
pkill -f "port.*$TEST_PORT_FRONTEND" 2>/dev/null || true
pkill -f "port.*$TEST_PORT_BACKEND" 2>/dev/null || true

log_success "Testing services fermati con successo!"