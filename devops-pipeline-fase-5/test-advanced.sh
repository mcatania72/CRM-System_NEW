#!/bin/bash

# =======================================
#   CRM System - Advanced Testing Suite
#   FASE 5: Enterprise Testing Strategy
#   Main Orchestrator for Testing
# =======================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/test-advanced.log"
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

log_test() {
    echo -e "${PURPLE}[TEST]${NC} 🧪 $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo "======================================="
    echo "   CRM System - Advanced Testing Suite"
    echo "   FASE 5: Enterprise Testing Strategy"
    echo "======================================="
}

# Show help
show_help() {
    echo "Usage: $0 [TEST_TYPE]"
    echo ""
    echo "Test Types:"
    echo "  unit         - Esegui solo unit tests"
    echo "  integration  - Esegui solo integration tests"
    echo "  e2e          - Esegui solo end-to-end tests"
    echo "  e2e-fast     - Esegui E2E tests semplificati (veloci)"
    echo "  performance  - Esegui solo performance tests"
    echo "  security     - Esegui solo security tests"
    echo "  all          - Esegui tutti i test (default)"
    echo "  report       - Genera solo report"
    echo "  help         - Mostra questo help"
    echo ""
    echo "Examples:"
    echo "  $0 unit                # Solo unit tests"
    echo "  $0 integration         # Solo integration tests"
    echo "  $0 e2e-fast           # E2E tests veloci (10-30s)"
    echo "  $0 all                 # Tutti i test"
    echo "  $0                     # Tutti i test (default)"
}

# Execute test modules
execute_test_module() {
    local test_type=$1
    local test_script="$SCRIPT_DIR/test-advanced/test-$test_type.sh"
    
    if [ -f "$test_script" ]; then
        log_test "Esecuzione $test_type tests..."
        bash "$test_script"
        return $?
    else
        log_error "Test script non trovato: $test_script"
        return 1
    fi
}

# Initialize test environment
init_test_environment() {
    log_info "Inizializzazione test environment..."
    
    # Check if testing services are running
    if ! curl -s "http://localhost:3101/api/health" >/dev/null 2>&1; then
        log_info "Avvio automatico testing services..."
        if [ -f "$SCRIPT_DIR/deploy-testing.sh" ]; then
            bash "$SCRIPT_DIR/deploy-testing.sh" start
        else
            log_error "deploy-testing.sh non trovato"
            return 1
        fi
    fi
    
    log_success "Test environment inizializzato"
}

# Generate comprehensive test report
generate_test_report() {
    log_info "Generazione report completo..."
    
    local report_script="$SCRIPT_DIR/test-advanced/generate-report.sh"
    if [ -f "$report_script" ]; then
        bash "$report_script"
    else
        log_error "Report generator non trovato: $report_script"
    fi
}

# Main execution
main() {
    print_header
    
    local test_type="${1:-all}"
    local overall_success=true
    
    case "$test_type" in
        "unit")
            init_test_environment
            execute_test_module "unit" || overall_success=false
            ;;
        "integration")
            init_test_environment
            execute_test_module "integration" || overall_success=false
            ;;
        "e2e")
            init_test_environment
            execute_test_module "e2e" || overall_success=false
            ;;
        "e2e-fast")
            init_test_environment
            log_test "Esecuzione E2E tests semplificati..."
            bash "$SCRIPT_DIR/test-advanced/test-e2e-simple.sh" || overall_success=false
            ;;
        "performance")
            init_test_environment
            execute_test_module "performance" || overall_success=false
            ;;
        "security")
            init_test_environment
            execute_test_module "security" || overall_success=false
            ;;
        "all")
            init_test_environment
            
            log_info "Esecuzione test suite completa..."
            
            execute_test_module "unit" || overall_success=false
            execute_test_module "integration" || overall_success=false
            
            # Use fast E2E by default for speed
            log_test "Esecuzione E2E tests semplificati..."
            bash "$SCRIPT_DIR/test-advanced/test-e2e-simple.sh" || overall_success=false
            
            execute_test_module "performance" || overall_success=false
            execute_test_module "security" || overall_success=false
            
            generate_test_report
            ;;
        "all-full")
            init_test_environment
            
            log_info "Esecuzione test suite completa con E2E full..."
            
            execute_test_module "unit" || overall_success=false
            execute_test_module "integration" || overall_success=false
            execute_test_module "e2e" || overall_success=false
            execute_test_module "performance" || overall_success=false
            execute_test_module "security" || overall_success=false
            
            generate_test_report
            ;;
        "report")
            generate_test_report
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "Test type non riconosciuto: $test_type"
            show_help
            exit 1
            ;;
    esac
    
    echo "\n======================================="
    if $overall_success; then
        log_success "ADVANCED TESTING SUITE: ALL TESTS COMPLETED SUCCESSFULLY! 🎉"
    else
        log_error "ADVANCED TESTING SUITE: SOME TESTS FAILED ❌"
    fi
    echo "======================================="
    
    # Return appropriate exit code
    if $overall_success; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"