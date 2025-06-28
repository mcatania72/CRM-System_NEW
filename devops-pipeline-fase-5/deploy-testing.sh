#!/bin/bash

# =======================================
#   CRM System - Testing Deployment
#   FASE 5: Enterprise Testing Strategy
#   Main Orchestrator for Testing Pipeline
# =======================================

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️ $1" | tee -a "$LOG_FILE"
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
    echo "  start        - Avvia testing pipeline completa"
    echo "  stop         - Ferma tutti i servizi testing"
    echo "  restart      - Riavvia testing pipeline"
    echo "  status       - Verifica status servizi"
    echo "  smoke        - Esegui smoke tests rapidi"
    echo "  cleanup      - Pulisci ambiente testing"
    echo "  help         - Mostra questo help"
    echo ""
    echo "Examples:"
    echo "  $0 start         # Avvia pipeline completa"
    echo "  $0 status        # Verifica stato"
    echo "  $0 smoke         # Test rapidi"
}

# Execute step modules
execute_step() {
    local step_name=$1
    local step_script="$SCRIPT_DIR/deploy-testing/deploy-testing-$step_name.sh"
    
    log_info "Esecuzione step: $step_name"
    
    if [ -f "$step_script" ]; then
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
    
    local command="${1:-start}"
    local overall_success=true
    
    case "$command" in
        "start")
            log_info "Avvio testing pipeline completa..."
            
            execute_step "prerequisites" || overall_success=false
            execute_step "environment" || overall_success=false
            execute_step "services" || overall_success=false
            execute_step "smoke-tests" || overall_success=false
            
            if $overall_success; then
                log_success "Testing pipeline avviata con successo!"
                log_info "Prossimi passi: ./test-advanced.sh [unit|integration|e2e|all]"
            else
                log_error "Errori durante l'avvio della pipeline"
            fi
            ;;
        "stop")
            execute_step "stop-services"
            ;;
        "restart")
            execute_step "stop-services"
            sleep 2
            execute_step "services"
            execute_step "smoke-tests"
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
            log_error "Comando non riconosciuto: $command"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    if $overall_success; then
        log_success "Deploy testing completato con successo! 🎉"
        exit 0
    else
        log_error "Deploy testing fallito ❌"
        exit 1
    fi
}

# Execute main function
main "$@"