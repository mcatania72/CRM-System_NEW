#!/bin/bash

# =======================================
#   CRM System - Testing Deployment
#   FASE 5: Enterprise Testing Strategy
#   Main Orchestrator Script
# =======================================

# NO set -e per gestire meglio gli errori

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/deploy-testing.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo "======================================="
    echo "   CRM System - Testing Deployment"
    echo "   FASE 5: Enterprise Testing Strategy"
    echo "======================================="
}

# Show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Avvia testing environment completo"
    echo "  stop      - Ferma testing services"
    echo "  restart   - Riavvia testing services"
    echo "  status    - Mostra status testing services"
    echo "  smoke     - Esegui smoke tests"
    echo "  cleanup   - Pulisci testing artifacts"
    echo "  help      - Mostra questo help"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Avvia testing environment"
    echo "  $0 status             # Verifica status"
    echo "  $0 smoke              # Quick tests"
    echo "  $0 stop               # Ferma tutto"
}

# Execute step scripts with error handling
execute_step() {
    local step_name=$1
    local step_script="$SCRIPT_DIR/deploy-testing/deploy-testing-$step_name.sh"
    
    if [ -f "$step_script" ]; then
        log_info "Esecuzione step: $step_name"
        if bash "$step_script"; then
            log_success "Step $step_name completato"
            return 0
        else
            log_error "Step $step_name fallito"
            return 1
        fi
    else
        log_error "Step script non trovato: $step_script"
        return 1
    fi
}

# Main execution
main() {
    print_header
    
    case "${1:-help}" in
        "start")
            execute_step "prerequisites" || exit 1
            execute_step "environment" || exit 1
            execute_step "services" || exit 1
            execute_step "smoke-tests" || exit 1
            ;;
        "stop")
            execute_step "stop-services"
            ;;
        "restart")
            execute_step "stop-services"
            sleep 2
            execute_step "environment" || exit 1
            execute_step "services" || exit 1
            execute_step "smoke-tests" || exit 1
            ;;
        "status")
            execute_step "status"
            ;;
        "smoke")
            execute_step "smoke-tests"
            ;;
        "cleanup")
            execute_step "cleanup"
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "Comando non riconosciuto: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"