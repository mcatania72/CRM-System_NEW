#!/bin/bash

# =======================================
#   Deploy Testing - Smart Status Check
#   FASE 5: Dynamic Port Status
# =======================================

# NO set -e per gestire meglio gli errori

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_warning() {
    echo -e "${YELLOW}[STATUS]${NC} ⚠️ $1"
}

log_info "Smart status check for testing services..."

# Load environment if exists
if [ -f "$HOME/devops-pipeline-fase-5/.env.testing" ]; then
    source "$HOME/devops-pipeline-fase-5/.env.testing"
    log_success "Loaded testing environment configuration"
else
    log_warning "No .env.testing found, using defaults"
    BACKEND_PORT=${BACKEND_PORT:-3101}
    FRONTEND_PORT=${FRONTEND_PORT:-3100}
fi

echo "=== TESTING SERVICES STATUS ==="

# Check backend
if curl -s "http://localhost:$BACKEND_PORT/api/health" >/dev/null 2>&1; then
    log_success "Backend: RUNNING on port $BACKEND_PORT"
    
    # Get detailed backend info
    local health_response=$(curl -s "http://localhost:$BACKEND_PORT/api/health" 2>/dev/null || echo "{}")
    echo "    Response: $health_response"
else
    log_error "Backend: NOT RUNNING on port $BACKEND_PORT"
fi

# Check frontend
if curl -s "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
    log_success "Frontend: RUNNING on port $FRONTEND_PORT"
    
    # Check if it's the right app
    if curl -s "http://localhost:$FRONTEND_PORT" | grep -q "CRM\|React\|vite"; then
        echo "    Detected: CRM Application"
    else
        echo "    Detected: Web Application"
    fi
else
    log_error "Frontend: NOT RUNNING on port $FRONTEND_PORT"
fi

echo ""
echo "=== PORT SCAN ==="

# Scan common ports for any running services
common_ports=(3000 3001 3002 3100 3101 3200 8080 9000)

for port in "${common_ports[@]}"; do
    if sudo lsof -i :$port >/dev/null 2>&1; then
        local process_info=$(sudo lsof -i :$port 2>/dev/null | tail -n +2 | head -1 | awk '{print $1, $2}')
        echo "  Port $port: OCCUPIED by $process_info"
    fi
done

echo ""
echo "=== TESTING TOOLS STATUS ==="
command -v jest >/dev/null 2>&1 && log_success "Jest: AVAILABLE" || log_error "Jest: NOT AVAILABLE"
command -v playwright >/dev/null 2>&1 && log_success "Playwright: AVAILABLE" || log_error "Playwright: NOT AVAILABLE"
command -v artillery >/dev/null 2>&1 && log_success "Artillery: AVAILABLE" || log_error "Artillery: NOT AVAILABLE"

echo ""
echo "=== TEST DATABASE STATUS ==="
test_database="$HOME/devops/CRM-System/testing/test.sqlite"
if [ -f "$test_database" ]; then
    db_size=$(du -h "$test_database" | cut -f1)
    log_success "Test Database: AVAILABLE ($db_size)"
else
    log_error "Test Database: NOT FOUND"
fi

echo ""
echo "=== CURRENT CONFIGURATION ==="
echo "Backend URL: http://localhost:$BACKEND_PORT"
echo "Frontend URL: http://localhost:$FRONTEND_PORT" 
echo "Test Database: $test_database"
echo "Environment file: $HOME/devops-pipeline-fase-5/.env.testing"

echo ""
echo "=== QUICK ACTIONS ==="
echo "Start services: ./deploy-testing/deploy-testing-cleanup-and-restart.sh restart"
echo "Setup test data: ./scripts/setup-test-data.sh"
echo "Run tests: ./test-advanced.sh all"
echo "Cleanup: ./deploy-testing/deploy-testing-cleanup-and-restart.sh cleanup"