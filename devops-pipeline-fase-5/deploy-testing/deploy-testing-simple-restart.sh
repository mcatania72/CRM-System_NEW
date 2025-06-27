#!/bin/bash

# =======================================
#   Deploy Testing - Simple BE/FE Restart
#   FASE 5: Focus on Backend/Frontend Only
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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️ $1"
}

log_action() {
    echo -e "${CYAN}[ACTION]${NC} ⚡ $1"
}

print_header() {
    echo "======================================="
    echo "   Simple Backend/Frontend Restart"
    echo "   FASE 5: Focus on BE/FE Only"
    echo "======================================="
}

# Function to kill only BE/FE processes
cleanup_be_fe() {
    log_info "=== CLEANING UP BACKEND/FRONTEND ONLY ==="
    
    # Kill Node.js development processes (BE/FE specific)
    log_action "Stopping Node.js development servers..."
    sudo pkill -f "npm.*run.*dev" 2>/dev/null || true
    sudo pkill -f "ts-node.*src/app.ts" 2>/dev/null || true  
    sudo pkill -f "vite" 2>/dev/null || true
    sudo pkill -f "nodemon" 2>/dev/null || true
    
    # Wait for graceful shutdown
    sleep 3
    
    # Clean testing PID files
    rm -f ~/backend-testing.pid ~/frontend-testing.pid 2>/dev/null || true
    rm -f ~/backend-testing.port ~/frontend-testing.port 2>/dev/null || true
    
    log_success "BE/FE cleanup completed"
}

# Function to start backend
start_backend() {
    log_info "=== STARTING BACKEND ==="
    
    local backend_port=3101
    
    # Check if port is free
    if sudo lsof -i :$backend_port >/dev/null 2>&1; then
        log_warning "Port $backend_port occupied, trying to free it..."
        sudo lsof -ti :$backend_port | xargs -r sudo kill -9 2>/dev/null
        sleep 2
    fi
    
    log_action "Starting backend on port $backend_port..."
    
    cd "$HOME/devops/CRM-System/backend" || { log_error "Cannot cd to backend"; return 1; }
    
    # Start backend
    TEST_MODE=true DATABASE_PATH="$HOME/devops/CRM-System/testing/test.sqlite" PORT=$backend_port npm run dev > "$HOME/backend-testing.log" 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$HOME/backend-testing.pid"
    echo $backend_port > "$HOME/backend-testing.port"
    
    # Wait and test
    log_info "Waiting for backend startup..."
    for i in {1..10}; do
        sleep 2
        if curl -s "http://localhost:$backend_port/api/health" >/dev/null 2>&1; then
            log_success "Backend started successfully on port $backend_port"
            return 0
        fi
        if [ $i -eq 10 ]; then
            log_error "Backend failed to start"
            log_error "Check logs: cat $HOME/backend-testing.log"
            return 1
        fi
    done
}

# Function to start frontend
start_frontend() {
    log_info "=== STARTING FRONTEND ==="
    
    local frontend_port=3100
    local backend_port=$(cat "$HOME/backend-testing.port" 2>/dev/null || echo "3101")
    
    # Check if port is free
    if sudo lsof -i :$frontend_port >/dev/null 2>&1; then
        log_warning "Port $frontend_port occupied, trying to free it..."
        sudo lsof -ti :$frontend_port | xargs -r sudo kill -9 2>/dev/null
        sleep 2
    fi
    
    log_action "Starting frontend on port $frontend_port (backend: $backend_port)..."
    
    cd "$HOME/devops/CRM-System/frontend" || { log_error "Cannot cd to frontend"; return 1; }
    
    # Start frontend with explicit port configuration
    VITE_PORT=$frontend_port PORT=$frontend_port VITE_API_BASE_URL="http://localhost:$backend_port/api" npm run dev > "$HOME/frontend-testing.log" 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$HOME/frontend-testing.pid"
    echo $frontend_port > "$HOME/frontend-testing.port"
    
    # Wait and test
    log_info "Waiting for frontend startup..."
    for i in {1..15}; do
        sleep 2
        if curl -s "http://localhost:$frontend_port" >/dev/null 2>&1; then
            log_success "Frontend started successfully on port $frontend_port"
            return 0
        fi
        if [ $i -eq 15 ]; then
            log_error "Frontend failed to start"
            log_error "Check logs: cat $HOME/frontend-testing.log"
            log_error "Last 10 lines of log:"
            tail -10 "$HOME/frontend-testing.log" 2>/dev/null || echo "No log file found"
            return 1
        fi
    done
}

# Function to show status
show_status() {
    local backend_port=$(cat "$HOME/backend-testing.port" 2>/dev/null || echo "3101")
    local frontend_port=$(cat "$HOME/frontend-testing.port" 2>/dev/null || echo "3100")
    
    echo ""
    echo "======================================="
    echo "   TESTING SERVICES STATUS"
    echo "======================================="
    
    # Backend status
    if curl -s "http://localhost:$backend_port/api/health" >/dev/null 2>&1; then
        log_success "Backend: http://localhost:$backend_port ✅"
    else
        log_error "Backend: http://localhost:$backend_port ❌"
    fi
    
    # Frontend status
    if curl -s "http://localhost:$frontend_port" >/dev/null 2>&1; then
        log_success "Frontend: http://localhost:$frontend_port ✅"
    else
        log_error "Frontend: http://localhost:$frontend_port ❌"
    fi
    
    echo ""
    echo "Next steps:"
    echo "• ./scripts/setup-test-data.sh          # Setup test data"
    echo "• ./test-advanced.sh unit               # Run unit tests"
    echo "• ./test-advanced.sh all                # Run all tests"
    echo ""
    
    # Save simple environment
    cat > "$HOME/devops-pipeline-fase-5/.env.testing" << EOF
# Simple Testing Environment
BACKEND_PORT=$backend_port
FRONTEND_PORT=$frontend_port
BACKEND_URL=http://localhost:$backend_port
FRONTEND_URL=http://localhost:$frontend_port
EOF
}

# Main execution
main() {
    print_header
    
    case "${1:-restart}" in
        "cleanup")
            cleanup_be_fe
            ;;
        "restart"|"start")
            cleanup_be_fe
            
            if start_backend; then
                if start_frontend; then
                    show_status
                    log_success "Backend/Frontend started successfully! 🎉"
                    exit 0
                else
                    log_error "Frontend startup failed"
                    exit 1
                fi
            else
                log_error "Backend startup failed"
                exit 1
            fi
            ;;
        "status")
            show_status
            ;;
        "help")
            echo "Usage: $0 [cleanup|restart|start|status|help]"
            echo ""
            echo "Commands:"
            echo "  cleanup  - Stop BE/FE processes only"
            echo "  restart  - Cleanup and start BE/FE (default)"
            echo "  start    - Same as restart"
            echo "  status   - Show current status"
            echo "  help     - Show this help"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use: $0 help"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"