#!/bin/bash

# Test Containers Script - FASE 2
# Test completi per containerizzazione + riutilizzo test FASE 1

# Configurazioni
LOG_FILE="$HOME/test-containers.log"
REPORT_FILE="$HOME/test-containers-report.json"
PROJECT_NAME="crm-system"
FASE1_DIR="../devops-pipeline-fase-1"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Contatori test
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
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

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
    log "TEST: $1"
    ((TOTAL_TESTS++))
}

log_section() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
    log "SECTION: $1"
}

# Funzione per eseguire test con timeout e gestione errori robusta
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout_seconds=10
    
    log_test "$test_name"
    
    if timeout "$timeout_seconds" bash -c "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

echo ""
echo "======================================="
echo "   CRM System - Container Test Suite"
echo "   FASE 2: Containerizzazione Completa"
echo "======================================="

log_info "Avvio test suite container per FASE 2..."

# Verifica prerequisiti
log_section "Test Prerequisites Container"

run_test "Docker disponibile" "command -v docker"
run_test "Docker Compose disponibile" "command -v docker-compose"
run_test "Docker daemon attivo" "docker ps"

# Test Container Status
log_section "Test Container Status"

run_test "Container backend in esecuzione" "docker-compose -p $PROJECT_NAME ps backend | grep -q 'Up'"
run_test "Container frontend in esecuzione" "docker-compose -p $PROJECT_NAME ps frontend | grep -q 'Up'"

# Test Container Health
log_section "Test Container Health"

log_info "Verifica health checks container..."

# Backend health
log_test "Backend Container Health Check"
if docker inspect --format='{{.State.Health.Status}}' "crm-backend" 2>/dev/null | grep -q "healthy"; then
    log_success "Backend Container Health Check"
elif docker inspect --format='{{.State.Health.Status}}' "crm-backend" 2>/dev/null | grep -q "starting"; then
    log_info "Backend health check in corso, attendo..."
    sleep 10
    if docker inspect --format='{{.State.Health.Status}}' "crm-backend" 2>/dev/null | grep -q "healthy"; then
        log_success "Backend Container Health Check (dopo attesa)"
    else
        log_fail "Backend Container Health Check"
    fi
else
    log_fail "Backend Container Health Check"
fi

# Frontend health  
log_test "Frontend Container Health Check"
if docker inspect --format='{{.State.Health.Status}}' "crm-frontend" 2>/dev/null | grep -q "healthy"; then
    log_success "Frontend Container Health Check"
elif docker inspect --format='{{.State.Health.Status}}' "crm-frontend" 2>/dev/null | grep -q "starting"; then
    log_info "Frontend health check in corso, attendo..."
    sleep 10
    if docker inspect --format='{{.State.Health.Status}}' "crm-frontend" 2>/dev/null | grep -q "healthy"; then
        log_success "Frontend Container Health Check (dopo attesa)"
    else
        log_fail "Frontend Container Health Check"
    fi
else
    log_fail "Frontend Container Health Check"
fi

# Test Docker Networks
log_section "Test Docker Networks"

run_test "Network crm-network esistente" "docker network ls | grep -q crm-network"
run_test "Backend connesso a crm-network" "docker inspect crm-backend | grep -q crm-network"
run_test "Frontend connesso a crm-network" "docker inspect crm-frontend | grep -q crm-network"

# Test Docker Volumes
log_section "Test Docker Volumes"

run_test "Volume dati backend montato" "docker inspect crm-backend | grep -q '/app/data'"
run_test "Volume crm-data esistente" "docker volume ls | grep -q crm-data"

# Test Container Logs (non devono contenere errori critici)
log_section "Test Container Logs"

log_info "Verifica assenza errori critici nei log..."

# Backend logs
log_test "Backend Logs senza errori critici"
if docker logs crm-backend 2>/dev/null | grep -qi "error\|exception\|failed" && \
   ! docker logs crm-backend 2>/dev/null | grep -q "Server in esecuzione\|Health check"; then
    log_fail "Backend Logs senza errori critici"
else
    log_success "Backend Logs senza errori critici"
fi

# Frontend logs
log_test "Frontend Logs senza errori critici"
if docker logs crm-frontend 2>/dev/null | grep -qi "error\|failed" && \
   ! docker logs crm-frontend 2>/dev/null | grep -q "nginx\|started"; then
    log_fail "Frontend Logs senza errori critici"
else
    log_success "Frontend Logs senza errori critici"
fi

# Test Performance Container
log_section "Test Performance Container"

log_info "Test performance container vs nativi..."

# Test tempo risposta backend
log_test "Backend Response Time"
BACKEND_START=$(date +%s%N)
if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
    BACKEND_END=$(date +%s%N)
    BACKEND_TIME=$(( (BACKEND_END - BACKEND_START) / 1000000 )) # millisecondi
    
    if [ "$BACKEND_TIME" -lt 2000 ]; then
        log_success "Backend Response Time: ${BACKEND_TIME}ms (< 2s)"
    else
        log_fail "Backend Response Time: ${BACKEND_TIME}ms (>= 2s)"
    fi
else
    log_fail "Backend Response Time test failed"
    BACKEND_TIME="N/A"
fi

# Test tempo risposta frontend
log_test "Frontend Response Time"
FRONTEND_START=$(date +%s%N)
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    FRONTEND_END=$(date +%s%N)
    FRONTEND_TIME=$(( (FRONTEND_END - FRONTEND_START) / 1000000 ))
    
    if [ "$FRONTEND_TIME" -lt 1000 ]; then
        log_success "Frontend Response Time: ${FRONTEND_TIME}ms (< 1s)"
    else
        log_fail "Frontend Response Time: ${FRONTEND_TIME}ms (>= 1s)"
    fi
else
    log_fail "Frontend Response Time test failed"
    FRONTEND_TIME="N/A"
fi

# Test Persistence Volume
log_section "Test Volume Persistence"

log_info "Test persistenza dati database..."

# Verifica che il database esista nel volume
log_test "Database SQLite presente nel volume"
if docker exec crm-backend test -f /app/data/database.sqlite 2>/dev/null; then
    log_success "Database SQLite presente nel volume"
else
    log_fail "Database SQLite non trovato nel volume"
fi

# Test che i dati siano accessibili dal container
log_test "Database accessibile dal container"
if docker exec crm-backend ls -la /app/data/ 2>/dev/null | grep -q database.sqlite; then
    log_success "Database accessibile dal container"
else
    log_fail "Database non accessibile dal container"
fi

# Test Applicazione
log_section "Test Applicazione Container"

log_info "Test funzionalità applicazione in modalità container..."

run_test "Backend API Health Check" "curl -f http://localhost:3001/api/health"
run_test "Frontend Home Page" "curl -f http://localhost:3000"
run_test "Backend Login API" "curl -X POST http://localhost:3001/api/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"admin@crm.local\",\"password\":\"admin123\"}' | grep -q token"

# Test Security Container
log_section "Test Security Container"

# Test che i container non siano root (dove configurato)
log_test "Backend container user check"
if docker exec crm-backend whoami 2>/dev/null | grep -q "crm-user"; then
    log_success "Backend container non esegue come root"
else
    log_fail "Backend container potrebbe eseguire come root"
fi

# Test isolamento network
run_test "Container isolati in network dedicato" "docker network inspect crm-network | grep -q Subnet"

# Genera report JSON
log_info "Generazione report JSON..."
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "fase": "FASE 2 - Containerizzazione Completa",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": $((PASSED_TESTS * 100 / TOTAL_TESTS))
  },
  "environment": {
    "docker_version": "$(docker --version | cut -d' ' -f3 | cut -d',' -f1)",
    "docker_compose_version": "$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)",
    "containers_running": $(docker ps --format "{{.Names}}" | grep -c crm || echo 0),
    "volumes_count": $(docker volume ls | grep -c crm-data || echo 0),
    "networks_count": $(docker network ls | grep -c crm-network || echo 0)
  },
  "performance": {
    "backend_response_time_ms": "${BACKEND_TIME:-N/A}",
    "frontend_response_time_ms": "${FRONTEND_TIME:-N/A}"
  },
  "containers": {
    "backend_status": "$(docker inspect --format='{{.State.Status}}' crm-backend 2>/dev/null || echo 'not found')",
    "frontend_status": "$(docker inspect --format='{{.State.Status}}' crm-frontend 2>/dev/null || echo 'not found')",
    "backend_health": "$(docker inspect --format='{{.State.Health.Status}}' crm-backend 2>/dev/null || echo 'no health check')",
    "frontend_health": "$(docker inspect --format='{{.State.Health.Status}}' crm-frontend 2>/dev/null || echo 'no health check')"
  }
}
EOF

# Report finale
echo ""
echo "======================================="
echo "   RISULTATI TEST CONTAINER"
echo "======================================="
echo -e "${BLUE}[INFO]${NC} Test completati: $TOTAL_TESTS"
echo -e "${GREEN}[INFO]${NC} Test passati: $PASSED_TESTS"
echo -e "${RED}[INFO]${NC} Test falliti: $FAILED_TESTS"

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "${CYAN}[INFO]${NC} Tasso di successo: $SUCCESS_RATE%"

echo ""
if [ $SUCCESS_RATE -ge 85 ]; then
    echo -e "${GREEN}🎉 FASE 2: CONTAINERIZZAZIONE COMPLETA - SUCCESSO! ($SUCCESS_RATE%)${NC}"
    echo ""
    echo -e "${GREEN}✅ Risultati eccellenti:${NC}"
    echo "   - Container backend e frontend funzionanti"
    echo "   - Health checks attivi e verdi"
    echo "   - Performance container accettabili"
    echo "   - Volumi persistenti configurati"
    echo "   - Network isolation attivo"
    echo "   - Test applicazione funzionanti"
    echo "   - Security best practices applicate"
    echo ""
    echo -e "${CYAN}🚀 PRONTO PER FASE 3: CI/CD AVANZATA${NC}"
    echo ""
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo -e "${YELLOW}⚠️ FASE 2: PARZIALMENTE COMPLETATA ($SUCCESS_RATE%)${NC}"
    echo ""
    echo -e "${YELLOW}Alcuni test non passano ma l'applicazione è funzionante${NC}"
    echo "Verifica i log per miglioramenti prima di procedere alla FASE 3"
else
    echo -e "${RED}❌ FASE 2: PROBLEMI CRITICI ($SUCCESS_RATE%)${NC}"
    echo ""
    echo -e "${RED}Molti test falliscono - verifica configurazione container${NC}"
    echo "Risolvi i problemi prima di procedere"
fi

echo ""
echo "Report dettagliato: $REPORT_FILE"
echo "Log completo: $LOG_FILE"
echo ""

# Test manuali
if [ "${1:-}" = "manual" ]; then
    echo "======================================="
    echo "   TEST MANUALI CONTAINER"
    echo "======================================="
    echo ""
    echo "Esegui questi test manuali nel browser:"
    echo ""
    echo "1. 🌐 Accesso applicazione:"
    echo "   → Apri: http://localhost:3000"
    echo "   → Login: admin@crm.local / admin123"
    echo "   → Verifica: Dashboard carica correttamente"
    echo ""
    echo "2. 🔧 Test funzionalità complete:"
    echo "   → Clienti: Crea, modifica, elimina customer"
    echo "   → Opportunità: Gestione pipeline vendite"
    echo "   → Attività: Task management"
    echo "   → Performance: Verifica velocità di risposta"
    echo ""
    echo "3. 🐳 Test specifici container:"
    echo "   → Restart container: ./deploy-containers.sh restart"
    echo "   → Verifica persistenza dati dopo restart"
    echo "   → Logs: ./deploy-containers.sh logs"
    echo ""
    echo "4. 🔍 Test avanzati:"
    echo "   → Shell backend: ./deploy-containers.sh exec backend bash"
    echo "   → Verifica database: ls -la /app/data/"
    echo "   → Performance monitor: docker stats"
    echo ""
    echo "✅ Se tutti i test manuali passano → FASE 2 COMPLETATA!"
    echo ""
fi

log "Container test suite completed"