#!/bin/bash

# test.sh
# Script per eseguire test automatizzati per FASE 1: Validazione Base
# Include test automatici e suggerimenti per test manuali

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurazione
PROJECT_DIR="$HOME/devops/CRM-System"
LOG_FILE="$HOME/test-fase1.log"
BACKEND_URL="http://localhost:3001"
FRONTEND_URL="http://localhost:3000"
TEST_RESULTS_FILE="$HOME/test-results-fase1.json"
TIMEOUT=30

# Contatori test
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Array per memorizzare risultati
declare -A TEST_RESULTS

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funzioni per output colorato
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[INFO]${NC} $message"
    log "$message"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

print_test_header() {
    echo -e "${CYAN}\\n=== $1 ===${NC}"
    log "TEST: $1"
}

# Funzione per eseguire un test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"  # Default: 0 (success)
    
    ((TOTAL_TESTS++))
    print_status $BLUE "Esecuzione test: $test_name"
    
    # Esegui il comando e cattura l'exit code
    if eval "$test_command" >/dev/null 2>&1; then
        local result=0
    else
        local result=1
    fi
    
    # Verifica il risultato
    if [ $result -eq $expected_result ]; then
        print_success "✓ $test_name - PASSED"
        TEST_RESULTS["$test_name"]="PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        print_error "✗ $test_name - FAILED"
        TEST_RESULTS["$test_name"]="FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Funzione per test HTTP
test_http_endpoint() {
    local test_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local timeout="${4:-10}"
    
    ((TOTAL_TESTS++))
    print_status $BLUE "Test HTTP: $test_name"
    
    local response=$(curl -s -w "%{http_code}" --connect-timeout $timeout "$url" 2>/dev/null || echo "000")
    local status_code="${response: -3}"
    
    if [ "$status_code" = "$expected_status" ]; then
        print_success "✓ $test_name - HTTP $status_code"
        TEST_RESULTS["$test_name"]="PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        print_error "✗ $test_name - HTTP $status_code (expected $expected_status)"
        TEST_RESULTS["$test_name"]="FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Test di connessione base
test_basic_connectivity() {
    print_test_header "Test Connettività Base"
    
    # Test ping localhost
    run_test "Ping Localhost" "ping -c 1 localhost"
    
    # Test risoluzione DNS
    run_test "DNS Resolution" "nslookup google.com"
    
    # Test connettività esterna
    run_test "External Connectivity" "curl -s --connect-timeout 5 https://www.google.com"
}

# Test prerequisiti
test_prerequisites() {
    print_test_header "Test Prerequisiti"
    
    # Test Node.js
    run_test "Node.js Available" "command -v node"
    run_test "Node.js Version >= 18" "node -e 'process.exit(parseInt(process.version.slice(1)) >= 18 ? 0 : 1)'"
    
    # Test npm
    run_test "npm Available" "command -v npm"
    run_test "npm Version >= 8" "npm -v | awk -F. '{exit \$1 >= 8 ? 0 : 1}'"
    
    # Test Git
    run_test "Git Available" "command -v git"
    
    # Test build tools
    run_test "Python3 Available" "command -v python3"
    run_test "Make Available" "command -v make"
    
    # Test directory structure
    run_test "Project Directory Exists" "test -d \"$PROJECT_DIR\""
    run_test "Backend Directory Exists" "test -d \"$PROJECT_DIR/backend\""
    run_test "Frontend Directory Exists" "test -d \"$PROJECT_DIR/frontend\""
    
    # Test package.json files
    run_test "Root package.json Exists" "test -f \"$PROJECT_DIR/package.json\""
    run_test "Backend package.json Exists" "test -f \"$PROJECT_DIR/backend/package.json\""
    run_test "Frontend package.json Exists" "test -f \"$PROJECT_DIR/frontend/package.json\""
}

# Test compilazione
test_compilation() {
    print_test_header "Test Compilazione"
    
    # Test backend compilation
    print_status $BLUE "Test compilazione backend..."
    cd "$PROJECT_DIR/backend"
    if npm run build >/dev/null 2>&1; then
        print_success "✓ Backend Compilation - PASSED"
        TEST_RESULTS["Backend Compilation"]="PASSED"
        ((PASSED_TESTS++))
    else
        print_error "✗ Backend Compilation - FAILED"
        TEST_RESULTS["Backend Compilation"]="FAILED"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Test frontend compilation
    print_status $BLUE "Test compilazione frontend..."
    cd "$PROJECT_DIR/frontend"
    if npm run build >/dev/null 2>&1; then
        print_success "✓ Frontend Compilation - PASSED"
        TEST_RESULTS["Frontend Compilation"]="PASSED"
        ((PASSED_TESTS++))
    else
        print_error "✗ Frontend Compilation - FAILED"
        TEST_RESULTS["Frontend Compilation"]="FAILED"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Verifica output di build
    run_test "Backend Build Output Exists" "test -d \"$PROJECT_DIR/backend/dist\""
    run_test "Frontend Build Output Exists" "test -d \"$PROJECT_DIR/frontend/dist\""
}

# Test servizi attivi
test_running_services() {
    print_test_header "Test Servizi Attivi"
    
    # Test backend endpoints
    test_http_endpoint "Backend Health Check" "$BACKEND_URL/api/health" "200"
    test_http_endpoint "Backend Root API" "$BACKEND_URL/api" "200"
    
    # Test frontend
    test_http_endpoint "Frontend Root" "$FRONTEND_URL" "200"
    
    # Test CORS
    run_test "CORS Headers Present" "curl -s -H 'Origin: http://localhost:3000' '$BACKEND_URL/api/health' -I | grep -i 'access-control-allow-origin'"
}

# Test autenticazione
test_authentication() {
    print_test_header "Test Autenticazione"
    
    # Test login con credenziali
    local login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@crm.local","password":"admin123"}' \
        "$BACKEND_URL/api/auth/login" 2>/dev/null)
    
    if echo "$login_response" | grep -q "token\|jwt"; then
        print_success "✓ Authentication Login - PASSED"
        TEST_RESULTS["Authentication Login"]="PASSED"
        ((PASSED_TESTS++))
    else
        print_error "✗ Authentication Login - FAILED"
        TEST_RESULTS["Authentication Login"]="FAILED"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Test database
test_database() {
    print_test_header "Test Database"
    
    # Test database file exists (SQLite)
    run_test "Database File Exists" "find \"$PROJECT_DIR\" -name '*.sqlite' -o -name '*.db' | head -1 | xargs test -f"
}

# Test performance base
test_basic_performance() {
    print_test_header "Test Performance Base"
    
    # Test tempo di risposta backend
    local backend_time=$(curl -s -w "%{time_total}" -o /dev/null "$BACKEND_URL/api/health" 2>/dev/null || echo "999")
    
    if (( $(echo "$backend_time < 2.0" | bc -l 2>/dev/null || echo "0") )); then
        print_success "✓ Backend Response Time (<2s) - PASSED"
        TEST_RESULTS["Backend Response Time"]="PASSED"
        ((PASSED_TESTS++))
    else
        print_warning "⚠ Backend Response Time (${backend_time}s) - SLOW"
        TEST_RESULTS["Backend Response Time"]="WARNING"
    fi
    ((TOTAL_TESTS++))
}

# Funzione per salvare risultati in JSON
save_test_results() {
    local timestamp=$(date -Iseconds)
    
    cat > "$TEST_RESULTS_FILE" << EOF
{
  "timestamp": "$timestamp",
  "phase": "FASE-1-Validazione-Base",
  "summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS,
    "success_rate": "$(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
  },
  "tests": {
EOF
    
    local first=true
    for test_name in "${!TEST_RESULTS[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> "$TEST_RESULTS_FILE"
        fi
        echo -n "    \"$test_name\": \"${TEST_RESULTS[$test_name]}\"" >> "$TEST_RESULTS_FILE"
        first=false
    done
    
    cat >> "$TEST_RESULTS_FILE" << EOF

  }
}
EOF
}

# Funzione per mostrare test manuali
show_manual_tests() {
    echo -e "${PURPLE}"
    echo "======================================="
    echo "   TEST MANUALI SUGGERITI"
    echo "======================================="
    echo -e "${NC}"
    
    echo "Dopo aver verificato che tutti i test automatici passano,"
    echo "esegui questi test manuali per una validazione completa:"
    echo ""
    
    echo -e "${YELLOW}1. Test Interface Frontend:${NC}"
    echo "   - Apri http://localhost:3000 nel browser"
    echo "   - Verifica che la pagina di login si carichi"
    echo "   - Verifica che non ci siano errori nella console del browser (F12)"
    echo ""
    
    echo -e "${YELLOW}2. Test Login:${NC}"
    echo "   - Email: admin@crm.local"
    echo "   - Password: admin123"
    echo "   - Verifica che il login sia successful"
    echo "   - Verifica redirect alla dashboard"
    echo ""
    
    echo -e "${YELLOW}3. Test Dashboard:${NC}"
    echo "   - Verifica che la dashboard si carichi"
    echo "   - Verifica presenza di widgets/statistiche"
    echo "   - Verifica che i dati si carichino (anche se vuoti)"
    echo ""
    
    echo -e "${YELLOW}4. Test Navigation:${NC}"
    echo "   - Clicca su 'Clienti' nel menu laterale"
    echo "   - Clicca su 'Opportunità' nel menu"
    echo "   - Clicca su 'Attività' nel menu"
    echo "   - Verifica che tutte le pagine si carichino senza errori"
    echo ""
    
    echo -e "${YELLOW}5. Test CRUD Base:${NC}"
    echo "   - Prova a creare un nuovo cliente"
    echo "   - Verifica che i form funzionino"
    echo "   - Verifica che i dati si salvino"
    echo "   - Prova a modificare il cliente creato"
    echo ""
    
    echo -e "${GREEN}Checklist Validazione Completa:${NC}"
    echo "☐ Tutti i test automatici passano"
    echo "☐ Login funziona correttamente"
    echo "☐ Dashboard si carica senza errori"
    echo "☐ Navigazione tra le pagine funziona"
    echo "☐ È possibile creare/modificare dati"
    echo "☐ API rispondono correttamente"
    echo "☐ Interfaccia è responsive"
    echo "☐ Performance accettabili"
    echo "☐ Nessun errore nei log"
    echo ""
}

# Main function
main() {
    # Banner
    echo -e "${BLUE}"
    echo "======================================="
    echo "   CRM System - Test Suite"
    echo "   FASE 1: Validazione Base"
    echo "======================================="
    echo -e "${NC}"
    
    # Inizializza log file
    echo "Test Fase 1 - $(date)" > "$LOG_FILE"
    
    print_status $BLUE "Avvio test suite per FASE 1..."
    
    # Installa bc se non disponibile (per calcoli)
    if ! command -v bc &> /dev/null; then
        print_status $YELLOW "Installazione bc per calcoli..."
        sudo apt-get update && sudo apt-get install -y bc
    fi
    
    # Esegui tutti i test
    test_basic_connectivity
    test_prerequisites
    test_compilation
    test_running_services
    test_authentication
    test_database
    test_basic_performance
    
    # Salva risultati
    save_test_results
    
    # Report finale
    echo -e "${GREEN}"
    echo "======================================="
    echo "   REPORT FINALE TEST FASE 1"
    echo "======================================="
    echo -e "${NC}"
    
    echo "Test totali eseguiti: $TOTAL_TESTS"
    echo -e "${GREEN}Test passati: $PASSED_TESTS${NC}"
    echo -e "${RED}Test falliti: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}Test saltati: $SKIPPED_TESTS${NC}"
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        local success_rate=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
        echo "Success rate: $success_rate%"
    fi
    
    echo ""
    echo "Log completo: $LOG_FILE"
    echo "Risultati JSON: $TEST_RESULTS_FILE"
    echo ""
    
    # Determina l'esito generale
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "🎉 FASE 1 - VALIDAZIONE COMPLETATA CON SUCCESSO!"
        echo ""
        show_manual_tests
        
        echo -e "${GREEN}\\n✅ Pronti per FASE 2: Containerizzazione Completa${NC}"
        log "FASE 1 completed successfully"
        exit 0
    else
        print_error "❌ FASE 1 - ALCUNI TEST SONO FALLITI"
        echo ""
        echo "Risolvi i seguenti problemi prima di procedere:"
        for test_name in "${!TEST_RESULTS[@]}"; do
            if [ "${TEST_RESULTS[$test_name]}" = "FAILED" ]; then
                echo -e "${RED}  ✗ $test_name${NC}"
            fi
        done
        echo ""
        echo "Suggerimenti:"
        echo "1. Verifica che l'applicazione sia in esecuzione: ./deploy.sh status"
        echo "2. Controlla i log: tail -f ~/backend.log ~/frontend.log"
        echo "3. Riavvia l'applicazione: ./deploy.sh restart"
        echo "4. Verifica prerequisiti: ./prerequisites.sh"
        echo ""
        log "FASE 1 completed with failures"
        exit 1
    fi
}

# Gestione parametri
case "${1:-}" in
    "manual")
        show_manual_tests
        exit 0
        ;;
    "report")
        if [ -f "$TEST_RESULTS_FILE" ]; then
            cat "$TEST_RESULTS_FILE"
        else
            print_error "File risultati non trovato. Esegui prima i test."
        fi
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Uso: $0 [manual|report]"
        echo "  (no args)  - Esegue tutti i test automatici"
        echo "  manual     - Mostra solo i test manuali"
        echo "  report     - Mostra l'ultimo report in formato JSON"
        exit 1
        ;;
esac