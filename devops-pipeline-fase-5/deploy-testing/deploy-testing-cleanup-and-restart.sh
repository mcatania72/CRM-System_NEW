#!/bin/bash

# =======================================
#   Deploy Testing - Cleanup and Restart
#   FASE 5: Smart Service Management
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
    echo -e "${BLUE}[CLEANUP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[CLEANUP]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[CLEANUP]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[CLEANUP]${NC} ⚠️ $1"
}

log_action() {
    echo -e "${CYAN}[ACTION]${NC} ⚡ $1"
}

print_header() {
    echo "======================================="
    echo "   Smart Testing Services Management"
    echo "   FASE 5: Cleanup & Restart"
    echo "======================================="
}

# Function to find processes using specific ports
find_port_processes() {
    local port=$1
    local pids=$(sudo lsof -ti :$port 2>/dev/null)
    echo "$pids"
}

# Function to kill processes gracefully
kill_processes_on_port() {
    local port=$1
    local service_name=$2
    
    log_info "Checking port $port for $service_name..."
    
    local pids=$(find_port_processes $port)
    
    if [ -n "$pids" ]; then
        log_warning "Found processes on port $port: $pids"
        
        # Try graceful shutdown first
        log_action "Attempting graceful shutdown..."
        echo "$pids" | xargs -r kill -TERM 2>/dev/null
        
        # Wait 5 seconds
        sleep 5
        
        # Check if still running
        local remaining_pids=$(find_port_processes $port)
        
        if [ -n "$remaining_pids" ]; then
            log_warning "Processes still running, forcing kill..."
            echo "$remaining_pids" | xargs -r sudo kill -KILL 2>/dev/null
            sleep 2
        fi
        
        # Final check
        local final_pids=$(find_port_processes $port)
        if [ -z "$final_pids" ]; then
            log_success "Port $port freed successfully"
        else
            log_error "Could not free port $port"
            return 1
        fi
    else
        log_success "Port $port already free"
    fi
    
    return 0
}

# Function to cleanup all known service patterns
cleanup_all_services() {
    log_info "=== COMPREHENSIVE SERVICE CLEANUP ==="
    
    # Kill by process patterns
    log_info "Killing known service patterns..."
    
    # Node.js development servers
    sudo pkill -f "npm.*run.*dev" 2>/dev/null || true
    sudo pkill -f "node.*dev" 2>/dev/null || true
    sudo pkill -f "ts-node" 2>/dev/null || true
    sudo pkill -f "vite" 2>/dev/null || true
    sudo pkill -f "nodemon" 2>/dev/null || true
    
    # Wait for graceful shutdown
    sleep 3
    
    # Port-specific cleanup
    log_info "=== PORT-SPECIFIC CLEANUP ==="
    
    # Standard development ports
    kill_processes_on_port 3000 "Frontend (standard)"
    kill_processes_on_port 3001 "Backend (standard)"
    kill_processes_on_port 3002 "Frontend (alt)"
    
    # Testing ports
    kill_processes_on_port 3100 "Frontend Testing"
    kill_processes_on_port 3101 "Backend Testing"
    
    # Jenkins and other services
    kill_processes_on_port 8080 "Jenkins"
    kill_processes_on_port 9000 "SonarQube"
    
    log_success "Service cleanup completed"
}

# Function to detect available ports
find_available_port() {
    local start_port=$1
    local max_attempts=20
    
    for ((i=0; i<max_attempts; i++)); do
        local test_port=$((start_port + i))
        if ! sudo lsof -i :$test_port >/dev/null 2>&1; then
            echo $test_port
            return 0
        fi
    done
    
    echo "0"
    return 1
}

# Function to start backend with smart port detection
start_backend_smart() {
    log_info "=== STARTING BACKEND SMARTLY ==="
    
    # Preferred ports in order
    local preferred_ports=(3101 3001 3201 3301)
    local backend_port=""
    
    for port in "${preferred_ports[@]}"; do
        if ! sudo lsof -i :$port >/dev/null 2>&1; then
            backend_port=$port
            break
        fi
    done
    
    if [ -z "$backend_port" ]; then
        backend_port=$(find_available_port 3101)
        if [ "$backend_port" = "0" ]; then
            log_error "No available ports for backend"
            return 1
        fi
    fi
    
    log_action "Starting backend on port $backend_port..."
    
    cd "$HOME/devops/CRM-System/backend" || { log_error "Cannot cd to backend"; return 1; }
    
    # Start backend with specific port
    TEST_MODE=true DATABASE_PATH="$HOME/devops/CRM-System/testing/test.sqlite" PORT="$backend_port" npm run dev > "$HOME/backend-testing.log" 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$HOME/backend-testing.pid"
    echo $backend_port > "$HOME/backend-testing.port"
    
    # Wait and test
    log_info "Waiting for backend startup..."
    for i in {1..15}; do
        sleep 2
        if curl -s "http://localhost:$backend_port/api/health" >/dev/null 2>&1; then
            log_success "Backend started successfully on port $backend_port"
            echo "BACKEND_PORT=$backend_port" > "$HOME/devops-pipeline-fase-5/.env.testing"
            return 0
        fi
        if [ $i -eq 15 ]; then
            log_error "Backend failed to start on port $backend_port"
            log_error "Check logs: cat $HOME/backend-testing.log"
            return 1
        fi
    done
}

# Function to start frontend with smart port detection
start_frontend_smart() {
    log_info "=== STARTING FRONTEND SMARTLY ==="
    
    # Get backend port
    local backend_port=$(cat "$HOME/backend-testing.port" 2>/dev/null || echo "3101")
    
    # Preferred ports in order
    local preferred_ports=(3100 3000 3002 3200 3300)
    local frontend_port=""
    
    for port in "${preferred_ports[@]}"; do
        if ! sudo lsof -i :$port >/dev/null 2>&1; then
            frontend_port=$port
            break
        fi
    done
    
    if [ -z "$frontend_port" ]; then
        frontend_port=$(find_available_port 3100)
        if [ "$frontend_port" = "0" ]; then
            log_error "No available ports for frontend"
            return 1
        fi
    fi
    
    log_action "Starting frontend on port $frontend_port (backend: $backend_port)..."
    
    cd "$HOME/devops/CRM-System/frontend" || { log_error "Cannot cd to frontend"; return 1; }
    
    # Start frontend with specific port and backend URL
    VITE_API_BASE_URL="http://localhost:$backend_port/api" VITE_PORT="$frontend_port" PORT="$frontend_port" npm run dev > "$HOME/frontend-testing.log" 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$HOME/frontend-testing.pid"
    echo $frontend_port > "$HOME/frontend-testing.port"
    
    # Wait and test
    log_info "Waiting for frontend startup..."
    for i in {1..20}; do
        sleep 2
        if curl -s "http://localhost:$frontend_port" >/dev/null 2>&1; then
            log_success "Frontend started successfully on port $frontend_port"
            echo "FRONTEND_PORT=$frontend_port" >> "$HOME/devops-pipeline-fase-5/.env.testing"
            return 0
        fi
        if [ $i -eq 20 ]; then
            log_error "Frontend failed to start on port $frontend_port"
            log_error "Check logs: cat $HOME/frontend-testing.log"
            return 1
        fi
    done
}

# Function to show final status
show_final_status() {
    local backend_port=$(cat "$HOME/backend-testing.port" 2>/dev/null || echo "unknown")
    local frontend_port=$(cat "$HOME/frontend-testing.port" 2>/dev/null || echo "unknown")
    
    echo ""
    echo "======================================="
    echo "   TESTING SERVICES STATUS"
    echo "======================================="
    
    # Backend status
    if curl -s "http://localhost:$backend_port/api/health" >/dev/null 2>&1; then
        log_success "Backend: http://localhost:$backend_port (RUNNING)"
    else
        log_error "Backend: http://localhost:$backend_port (NOT RESPONDING)"
    fi
    
    # Frontend status
    if curl -s "http://localhost:$frontend_port" >/dev/null 2>&1; then
        log_success "Frontend: http://localhost:$frontend_port (RUNNING)"
    else
        log_error "Frontend: http://localhost:$frontend_port (NOT RESPONDING)"
    fi
    
    echo ""
    echo "Next steps:"
    echo "• ./scripts/setup-test-data.sh          # Setup test data"
    echo "• ./deploy-testing/deploy-testing-smoke-tests.sh  # Quick smoke tests"
    echo "• ./test-advanced.sh all                 # Full test suite"
    echo ""
    
    # Save environment for other scripts
    cat > "$HOME/devops-pipeline-fase-5/.env.testing" << EOF
# Testing Environment Configuration
# Generated on $(date)
BACKEND_PORT=$backend_port
FRONTEND_PORT=$frontend_port
BACKEND_URL=http://localhost:$backend_port
FRONTEND_URL=http://localhost:$frontend_port
TEST_DATABASE_PATH=$HOME/devops/CRM-System/testing/test.sqlite
EOF
    
    log_success "Environment saved to .env.testing"
}

# Main execution
main() {
    print_header
    
    case "${1:-restart}" in
        "cleanup")
            cleanup_all_services
            ;;
        "restart"|"start")
            cleanup_all_services
            
            log_info "=== STARTING SERVICES WITH SMART PORT DETECTION ==="
            
            if start_backend_smart; then
                if start_frontend_smart; then
                    show_final_status
                    log_success "All testing services started successfully! 🎉"
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
            show_final_status
            ;;
        "help")
            echo "Usage: $0 [cleanup|restart|start|status|help]"
            echo ""
            echo "Commands:"
            echo "  cleanup  - Kill all services and free ports"
            echo "  restart  - Cleanup and start services (default)"
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