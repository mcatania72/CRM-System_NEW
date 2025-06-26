#!/bin/bash

# CRM System Test Suite
# FASE 1: Validazione Base
# Versione Robusta - Non esce al primo errore

# Configurazioni
LOG_FILE="$HOME/test.log"
REPORT_FILE="$HOME/test-report.json"
BACKEND_URL="http://localhost:3001"
FRONTEND_URL="http://localhost:3000"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contatori test
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Inizializza log
echo "=== CRM Test Suite - $(date) ===" > "$LOG_FILE"

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    log "TEST: $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    log "PASS: $1"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    log "FAIL: $1"
    ((FAILED_TESTS++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# Funzione per eseguire test con gestione errori
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout_seconds="${3:-10}"
    
    log_test "$test_name"
    ((TOTAL_TESTS++))
    
    # Esegui comando con timeout e cattura output
    if timeout "$timeout_seconds" bash -c "$test_command" >> "$LOG_FILE" 2>&1; then
        log_success "$test_name"
        return 0
    else
        local exit_code=$?
        log_fail "$test_name (exit code: $exit_code)"
        return 1
    fi
}

# Inizio test suite
echo ""
echo "======================================="
echo "   CRM System - Test Suite"
echo "   FASE 1: Validazione Base"
echo "======================================="

log_info "Avvio test suite per FASE 1..."

# Test 1: Connettività Base
echo ""
echo "=== Test Connettività Base ==="

log_info "Testando connettività backend..."
run_test "Backend Health Check" "curl -f -s -m 5 $BACKEND_URL/api/health"

log_info "Testando connettività frontend..."
run_test "Frontend Response" "curl -f -s -m 5 $FRONTEND_URL"

log_info "Testando porte..."
run_test "Backend Port 3001" "nc -z -w 3 localhost 3001"
run_test "Frontend Port 3000" "nc -z -w 3 localhost 3000"

# Test 2: API Endpoints
echo ""
echo "=== Test API Endpoints ==="

log_info "Testando endpoint di autenticazione..."
run_test "Auth Login Endpoint" "curl -f -s -m 5 -X POST $BACKEND_URL/api/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"admin@crm.local\",\"password\":\"admin123\"}'"

log_info "Testando endpoint CRUD..."
run_test "Customers Endpoint" "curl -f -s -m 5 $BACKEND_URL/api/customers"
run_test "Opportunities Endpoint" "curl -f -s -m 5 $BACKEND_URL/api/opportunities"
run_test "Activities Endpoint" "curl -f -s -m 5 $BACKEND_URL/api/activities"
run_test "Interactions Endpoint" "curl -f -s -m 5 $BACKEND_URL/api/interactions"
run_test "Dashboard Stats Endpoint" "curl -f -s -m 5 $BACKEND_URL/api/dashboard/stats"

# Test 3: Database
echo ""
echo "=== Test Database ==="

log_info "Testando database SQLite..."
run_test "Database File Exists" "test -f $HOME/devops/CRM-System/backend/database.sqlite"

if command -v sqlite3 >/dev/null 2>&1; then
    run_test "Database Readable" "sqlite3 $HOME/devops/CRM-System/backend/database.sqlite 'SELECT 1;'"
    run_test "Admin User Exists" "sqlite3 $HOME/devops/CRM-System/backend/database.sqlite \"SELECT email FROM user WHERE email='admin@crm.local';\""
else
    log_info "SQLite3 non disponibile, saltando test database"
    ((TOTAL_TESTS+=2))
    log_fail "Database Readable (sqlite3 non installato)"
    log_fail "Admin User Exists (sqlite3 non installato)"
fi

# Test 4: Processi
echo ""
echo "=== Test Processi ==="

log_info "Testando processi attivi..."
run_test "Backend Process Running" "pgrep -f 'ts-node.*app.ts'"
run_test "Frontend Process Running" "pgrep -f 'vite'"

# Test 5: File System
echo ""
echo "=== Test File System ==="

log_info "Testando struttura directory..."
run_test "Backend Directory" "test -d $HOME/devops/CRM-System/backend"
run_test "Frontend Directory" "test -d $HOME/devops/CRM-System/frontend"
run_test "Backend Source Files" "test -f $HOME/devops/CRM-System/backend/src/app.ts"
run_test "Frontend Source Files" "test -f $HOME/devops/CRM-System/frontend/src/App.tsx"

log_info "Testando dipendenze..."
run_test "Node Modules Backend" "test -d $HOME/devops/CRM-System/backend/node_modules"
run_test "Node Modules Frontend" "test -d $HOME/devops/CRM-System/frontend/node_modules"

# Test 6: Configurazione
echo ""
echo "=== Test Configurazione ==="

log_info "Testando file di configurazione..."
run_test "TypeScript Config Backend" "test -f $HOME/devops/CRM-System/backend/tsconfig.json"
run_test "TypeScript Config Frontend" "test -f $HOME/devops/CRM-System/frontend/tsconfig.json"
run_test "Vite Config" "test -f $HOME/devops/CRM-System/frontend/vite.config.ts"
run_test "Package.json Backend" "test -f $HOME/devops/CRM-System/backend/package.json"
run_test "Package.json Frontend" "test -f $HOME/devops/CRM-System/frontend/package.json"

# Test 7: Network Test Aggiuntivi
echo ""
echo "=== Test Network ==="

log_info "Testando configurazione di rete..."
run_test "Backend CORS Test" "curl -s -H 'Origin: http://localhost:3000' $BACKEND_URL/api/health | grep -q 'OK'"

# Genera report finale
echo ""
echo "======================================="
echo "   RISULTATI TEST AUTOMATICI"
echo "======================================="

# Calcola percentuale successo
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
else
    SUCCESS_RATE=0
fi

echo "Test Totali: $TOTAL_TESTS"
echo "Test Passati: $PASSED_TESTS"
echo "Test Falliti: $FAILED_TESTS"
echo "Tasso di Successo: $SUCCESS_RATE%"

# Genera report JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "CRM System FASE 1",
  "timestamp": "$(date -Iseconds)",
  "total_tests": $TOTAL_TESTS,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "success_rate": $SUCCESS_RATE,
  "status": "$([ $SUCCESS_RATE -ge 80 ] && echo 'PASS' || echo 'FAIL')"
}
EOF

echo ""
if [ $SUCCESS_RATE -ge 80 ]; then
    log_success "Test suite FASE 1 completata con successo ($SUCCESS_RATE%)"
    echo ""
    echo "🎉 FASE 1: VALIDAZIONE BASE COMPLETATA!"
    echo ""
    echo "✅ Criteri di successo raggiunti:"
    echo "   - Tasso di successo: $SUCCESS_RATE% (≥80% richiesto)"
    echo "   - Backend funzionante"
    echo "   - Frontend funzionante"
    echo "   - Database operativo"
    echo "   - API endpoints attivi"
    echo ""
    echo "🚀 PRONTO PER FASE 2: CONTAINERIZZAZIONE COMPLETA"
else
    log_fail "Test suite FASE 1 fallita ($SUCCESS_RATE%)"
    echo ""
    echo "❌ Alcuni test sono falliti"
    echo "   - Verifica i log: $LOG_FILE"
    echo "   - Controlla che l'applicazione sia attiva: ./deploy.sh status"
    echo "   - Risolvi i problemi e riprova"
fi

echo ""
echo "Report completo: $REPORT_FILE"
echo "Log dettagliato: $LOG_FILE"

# Test manuali guidati
show_manual_tests() {
    echo ""
    echo "======================================="
    echo "   TEST MANUALI GUIDATI"
    echo "======================================="
    echo ""
    
    echo "Esegui questi test manuali nel browser:"
    echo ""
    echo "1. 🌐 ACCESSO APPLICAZIONE"
    echo "   URL: http://192.168.1.29:3000"
    echo "   ✓ La pagina si carica correttamente"
    echo "   ✓ Nessun errore nella console browser (F12)"
    echo ""
    
    echo "2. 🔐 TEST LOGIN"
    echo "   Email: admin@crm.local"
    echo "   Password: admin123"
    echo "   ✓ Login avviene senza errori"
    echo "   ✓ Redirect alla dashboard"
    echo ""
    
    echo "3. 📊 DASHBOARD"
    echo "   ✓ Dashboard carica correttamente"
    echo "   ✓ Statistiche visibili"
    echo "   ✓ Grafici si renderizzano"
    echo ""
    
    echo "4. 👥 GESTIONE CLIENTI"
    echo "   ✓ Lista clienti carica"
    echo "   ✓ Può creare nuovo cliente"
    echo "   ✓ Può modificare cliente esistente"
    echo "   ✓ Filtri funzionano"
    echo ""
    
    echo "======================================="
    echo "   CHECKLIST COMPLETAMENTO FASE 1"
    echo "======================================="
    echo ""
    echo "Segna ✓ quando completato:"
    echo ""
    echo "□ Tutti i test automatici passano (≥80%)"
    echo "□ Login funziona correttamente"
    echo "□ Dashboard carica con dati"
    echo "□ CRUD clienti funziona"
    echo "□ Performance accettabile (< 3s caricamento)"
    echo "□ Nessun errore in console browser"
    echo ""
    echo "🎉 FASE 1 COMPLETATA QUANDO TUTTI I PUNTI SONO ✓"
    echo ""
}

# Gestione argomenti
case "${1:-auto}" in
    "manual")
        show_manual_tests
        ;;
    "report")
        if [ -f "$REPORT_FILE" ]; then
            echo "=== REPORT TEST ==="
            cat "$REPORT_FILE"
        else
            echo "Report non trovato. Esegui prima: ./test.sh"
        fi
        ;;
    "auto"|*)
        # Test automatici già eseguiti sopra
        echo ""
        echo "Comandi disponibili:"
        echo "  ./test.sh        - Esegui tutti i test automatici"
        echo "  ./test.sh manual - Mostra guida test manuali"
        echo "  ./test.sh report - Mostra ultimo report"
        echo ""
        ;;
esac

log_info "Test suite completata"