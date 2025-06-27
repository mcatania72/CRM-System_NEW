#!/bin/bash

# =======================================
#   Deploy Testing - Simple BE/FE Restart
#   FASE 5: Focus on Backend/Frontend Only
#   VERSION 2: Auto-detect actual ports
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
    echo "   FASE 5: Auto-Detect Actual Ports"
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

# Function to detect frontend port from log
detect_frontend_port() {
    local log_file="$1"
    local detected_port=""
    
    # Wait a bit for log to be written
    sleep 3
    
    # Look for "Local: http://localhost:PORT/" in log
    if [ -f "$log_file" ]; then
        detected_port=$(grep -o "Local:.*http://localhost:[0-9]*" "$log_file" | grep -o "[0-9]*" | head -1)
    fi
    
    echo "$detected_port"
}

# Function to start frontend
start_frontend() {
    log_info "=== STARTING FRONTEND ==="
    
    local preferred_port=3100
    local backend_port=$(cat "$HOME/backend-testing.port" 2>/dev/null || echo "3101")
    
    log_action "Starting frontend (preferred port: $preferred_port, backend: $backend_port)..."
    
    cd "$HOME/devops/CRM-System/frontend" || { log_error "Cannot cd to frontend"; return 1; }
    
    # Start frontend and let Vite choose port if needed
    VITE_PORT=$preferred_port PORT=$preferred_port VITE_API_BASE_URL="http://localhost:$backend_port/api" npm run dev > "$HOME/frontend-testing.log" 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$HOME/frontend-testing.pid"
    
    # Wait and detect actual port
    log_info "Waiting for frontend startup and detecting actual port..."
    local actual_port=""
    
    for i in {1..15}; do
        sleep 2
        
        # Try to detect port from log
        actual_port=$(detect_frontend_port "$HOME/frontend-testing.log")
        
        if [ -n "$actual_port" ]; then
            # Test if frontend responds on detected port
            if curl -s "http://localhost:$actual_port" >/dev/null 2>&1; then
                echo $actual_port > "$HOME/frontend-testing.port"
                log_success "Frontend started successfully on port $actual_port"
                if [ "$actual_port" != "$preferred_port" ]; then
                    log_warning "Frontend started on $actual_port instead of preferred $preferred_port"
                fi
                return 0
            fi
        fi
        
        # Also try preferred port
        if curl -s "http://localhost:$preferred_port" >/dev/null 2>&1; then
            echo $preferred_port > "$HOME/frontend-testing.port"
            log_success "Frontend started successfully on port $preferred_port"
            return 0
        fi
        
        if [ $i -eq 15 ]; then
            log_error "Frontend failed to start or detect port"
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
        
        # Try common ports if detection failed
        log_info "Scanning common ports for frontend..."
        for port in 3000 3001 3002 3100 3200; do
            if curl -s "http://localhost:$port" >/dev/null 2>&1; then
                log_warning "Found frontend on port $port instead!"
                echo $port > "$HOME/frontend-testing.port"
                frontend_port=$port
                break
            fi
        done
    fi
    
    echo ""
    echo "Actual URLs:"
    echo "• Backend:  http://localhost:$backend_port"
    echo "• Frontend: http://localhost:$frontend_port"
    echo ""
    echo "Next steps:"
    echo "• ./scripts/setup-test-data.sh          # Setup test data"
    echo "• ./test-advanced.sh unit               # Run unit tests"
    echo "• ./test-advanced.sh all                # Run all tests"
    echo ""
    
    # Save actual environment
    cat > "$HOME/devops-pipeline-fase-5/.env.testing" << EOF
# Testing Environment (Auto-Detected Ports)
BACKEND_PORT=$backend_port
FRONTEND_PORT=$frontend_port
BACKEND_URL=http://localhost:$backend_port
FRONTEND_URL=http://localhost:$frontend_port
EOF
    
    log_success "Environment saved with actual ports: BE=$backend_port, FE=$frontend_port"
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