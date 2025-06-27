#!/bin/bash

# =======================================
#   Deploy Testing - Services Management
#   FASE 5: Step 3 (FIXED - No set -e)
# =======================================

# NO set -e per gestire meglio gli errori

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
log_info "Stopping existing services on testing ports..."
pkill -f "port.*$TEST_PORT_FRONTEND" 2>/dev/null
pkill -f "port.*$TEST_PORT_BACKEND" 2>/dev/null

# Wait a moment for processes to stop
sleep 2

if [ ! -d "$HOME/devops/CRM-System" ]; then
    log_error "CRM-System directory non trovato"
    exit 1
fi

cd "$HOME/devops/CRM-System" || { log_error "Cannot cd to CRM-System"; exit 1; }

# Start backend in testing mode
log_info "Avvio backend testing (porta $TEST_PORT_BACKEND)..."
if [ -d "backend" ]; then
    cd backend || { log_error "Cannot cd to backend"; exit 1; }
    
    # Start backend
    TEST_MODE=true DATABASE_PATH="$TEST_DATABASE" PORT="$TEST_PORT_BACKEND" npm run dev > "$HOME/backend-testing.log" 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$HOME/backend-testing.pid"
    
    # Wait for backend
    log_info "Waiting for backend to start..."
    for i in {1..10}; do
        sleep 2
        if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" >/dev/null 2>&1; then
            log_success "Backend testing avviato (porta $TEST_PORT_BACKEND)"
            break
        fi
        if [ $i -eq 10 ]; then
            log_error "Backend testing non avviato correttamente"
            log_error "Check logs: cat $HOME/backend-testing.log"
            exit 1
        fi
    done
else
    log_error "Backend directory non trovato"
    exit 1
fi

# Start frontend in testing mode
log_info "Avvio frontend testing (porta $TEST_PORT_FRONTEND)..."
cd "$HOME/devops/CRM-System/frontend" || { log_error "Cannot cd to frontend"; exit 1; }

VITE_API_BASE_URL="http://localhost:$TEST_PORT_BACKEND/api" VITE_PORT="$TEST_PORT_FRONTEND" npm run dev > "$HOME/frontend-testing.log" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$HOME/frontend-testing.pid"

# Wait for frontend
log_info "Waiting for frontend to start..."
for i in {1..15}; do
    sleep 2
    if curl -s "http://localhost:$TEST_PORT_FRONTEND" >/dev/null 2>&1; then
        log_success "Frontend testing avviato (porta $TEST_PORT_FRONTEND)"
        break
    fi
    if [ $i -eq 15 ]; then
        log_error "Frontend testing non avviato correttamente"
        log_error "Check logs: cat $HOME/frontend-testing.log"
        exit 1
    fi
done

log_success "Testing services avviati con successo!"
log_info "Frontend: http://localhost:$TEST_PORT_FRONTEND"
log_info "Backend: http://localhost:$TEST_PORT_BACKEND"
exit 0