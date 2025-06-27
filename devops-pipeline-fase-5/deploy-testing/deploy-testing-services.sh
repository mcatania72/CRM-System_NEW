#!/bin/bash

# =======================================
#   Deploy Testing - Services Management
#   FASE 5: Step 3
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[SERVICES]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SERVICES]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[SERVICES]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[SERVICES]${NC} ⚠️ $1"
}

# Testing configuration
TEST_DATABASE="$HOME/devops/CRM-System/testing/test.sqlite"
TEST_PORT_FRONTEND=3100
TEST_PORT_BACKEND=3101

log_info "Avvio testing services..."

# Stop any existing services on testing ports
pkill -f "port.*$TEST_PORT_FRONTEND" 2>/dev/null || true
pkill -f "port.*$TEST_PORT_BACKEND" 2>/dev/null || true

cd "$HOME/devops/CRM-System"

# Start backend in testing mode
log_info "Avvio backend testing (porta $TEST_PORT_BACKEND)..."
cd backend
TEST_MODE=true DATABASE_PATH="$TEST_DATABASE" PORT="$TEST_PORT_BACKEND" npm run dev > "$HOME/backend-testing.log" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$HOME/backend-testing.pid"

# Wait for backend
sleep 5

# Check if backend is running
if ! curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" >/dev/null; then
    log_error "Backend testing non avviato correttamente"
    cat "$HOME/backend-testing.log"
    exit 1
fi

log_success "Backend testing avviato (porta $TEST_PORT_BACKEND)"

# Start frontend in testing mode
log_info "Avvio frontend testing (porta $TEST_PORT_FRONTEND)..."
cd ../frontend
VITE_API_BASE_URL="http://localhost:$TEST_PORT_BACKEND/api" VITE_PORT="$TEST_PORT_FRONTEND" npm run dev > "$HOME/frontend-testing.log" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$HOME/frontend-testing.pid"

# Wait for frontend
sleep 10

# Check if frontend is running
if ! curl -s "http://localhost:$TEST_PORT_FRONTEND" >/dev/null; then
    log_error "Frontend testing non avviato correttamente"
    cat "$HOME/frontend-testing.log"
    exit 1
fi

log_success "Frontend testing avviato (porta $TEST_PORT_FRONTEND)"
log_success "Testing services avviati con successo!"
log_info "Frontend: http://localhost:$TEST_PORT_FRONTEND"
log_info "Backend: http://localhost:$TEST_PORT_BACKEND"