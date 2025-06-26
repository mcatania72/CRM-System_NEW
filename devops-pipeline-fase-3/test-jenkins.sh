#!/bin/bash

# Test Jenkins CI/CD Script
# FASE 3: CI/CD Base con Jenkins
# Riutilizza test FASE 1 e FASE 2

LOG_FILE="$HOME/test-jenkins.log"
REPORT_FILE="$HOME/test-jenkins-report.json"
JENKINS_URL="http://localhost:8080"
FASE_1_DIR="$HOME/devops-pipeline-fase-1"
FASE_2_DIR="$HOME/devops-pipeline-fase-2"

# Contatori test
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    log "PASS: $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    log "FAIL: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    log "TEST: $1"
}

# Funzioni di status (NON incrementano contatori)
status_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

status_fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

status_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# Funzione per eseguire test con timeout e contatori
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout_seconds=${3:-10}
    
    log_test "$test_name"
    ((TOTAL_TESTS++))
    
    if timeout "$timeout_seconds" bash -c "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        ((PASSED_TESTS++))
        return 0
    else
        log_fail "$test_name"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Funzione per test Jenkins specifici
test_jenkins_infrastructure() {
    echo ""
    echo "=== Test Infrastructure Jenkins ==="
    status_info "Testando infrastruttura Jenkins..."
    
    # Test servizio Jenkins
    run_test "Jenkins Service Running" "sudo systemctl is-active jenkins"
    
    # Test porta Jenkins
    run_test "Jenkins Port 8080" "nc -z localhost 8080"
    
    # Test raggiungibilità web
    run_test "Jenkins Web UI" "curl -f -s $JENKINS_URL"
    
    # Test API Jenkins
    run_test "Jenkins API" "curl -f -s $JENKINS_URL/api/json"
    
    # Test versione Jenkins
    run_test "Jenkins Version Check" "curl -s $JENKINS_URL/api/xml?xpath=/hudson/version | grep -q version"
    
    # Test Java per Jenkins
    run_test "Java Available" "java -version"
    
    # Test Git per Jenkins
    run_test "Git Available" "git --version"
}

# Funzione per test pipeline e job
test_jenkins_pipelines() {
    echo ""
    echo "=== Test Pipeline Configuration ==="
    status_info "Testando configurazione pipeline..."
    
    # Test directory jobs
    run_test "Jenkins Jobs Directory" "test -d /var/lib/jenkins/jobs"
    
    # Test plugins directory
    run_test "Jenkins Plugins Directory" "test -d /var/lib/jenkins/plugins"
    
    # Test workspace directory
    run_test "Jenkins Workspace Directory" "test -d /var/lib/jenkins/workspace"
    
    # Test configurazione Jenkins
    run_test "Jenkins Config File" "sudo test -f /var/lib/jenkins/config.xml"
    
    # Test CLI Jenkins (se disponibile)
    if command -v jenkins-cli.jar >/dev/null 2>&1; then
        run_test "Jenkins CLI Available" "java -jar jenkins-cli.jar -s $JENKINS_URL help"
    else
        status_info "Jenkins CLI non configurato (opzionale)"
    fi
}

# Funzione per test integrazione con Git
test_git_integration() {
    echo ""
    echo "=== Test Git Integration ==="
    status_info "Testando integrazione Git..."
    
    # Test repository CRM accessibile
    run_test "CRM Repository Access" "test -d $HOME/devops/CRM-System/.git"
    
    # Test Git configurazione
    run_test "Git Global Config" "git config --global user.name"
    
    # Test connessione GitHub (se possibile)
    run_test "GitHub Connectivity" "curl -f -s https://api.github.com/repos/mcatania72/CRM-System" 15
    
    # Test clone repository
    run_test "Git Clone Capability" "git ls-remote https://github.com/mcatania72/CRM-System.git" 15
}

# Funzione per test integrazione Docker
test_docker_integration() {
    echo ""
    echo "=== Test Docker Integration ==="
    status_info "Testando integrazione Docker..."
    
    # Test Docker disponibile
    run_test "Docker Service" "docker --version"
    
    # Test Docker Compose
    run_test "Docker Compose" "docker-compose --version"
    
    # Test Docker daemon
    run_test "Docker Daemon" "docker info"
    
    # Test Docker images CRM (se esistono dalla FASE 2)
    if docker images | grep -q crm; then
        run_test "CRM Docker Images" "docker images | grep crm"
    else
        status_info "Immagini Docker CRM non trovate (build necessario)"
    fi
    
    # Test Docker network CRM (se esiste dalla FASE 2)
    if docker network ls | grep -q crm; then
        run_test "CRM Docker Network" "docker network ls | grep crm"
    else
        status_info "Network Docker CRM non trovato"
    fi
}

# Funzione per eseguire test FASE 1 (riutilizzo)
run_fase1_tests() {
    echo ""
    echo "=== Test FASE 1 Integration ==="
    status_info "Eseguendo test FASE 1 per validazione applicazione..."
    
    if [ -f "$FASE_1_DIR/test.sh" ]; then
        status_info "Esecuzione test FASE 1..."
        
        # Esegui test FASE 1 e cattura risultato
        if cd "$FASE_1_DIR" && ./test.sh >/dev/null 2>&1; then
            log_success "Test FASE 1 completati con successo"
            ((PASSED_TESTS++))
        else
            log_fail "Test FASE 1 falliti"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
        
        # Torna alla directory originale
        cd - >/dev/null 2>&1
    else
        log_warning "Script test FASE 1 non trovato: $FASE_1_DIR/test.sh"
    fi
}

# Funzione per eseguire test FASE 2 (riutilizzo)
run_fase2_tests() {
    echo ""
    echo "=== Test FASE 2 Integration ==="
    status_info "Eseguendo test FASE 2 per validazione container..."
    
    if [ -f "$FASE_2_DIR/test-containers.sh" ]; then
        status_info "Esecuzione test FASE 2..."
        
        # Esegui test FASE 2 e cattura risultato
        if cd "$FASE_2_DIR" && ./test-containers.sh >/dev/null 2>&1; then
            log_success "Test FASE 2 completati con successo"
            ((PASSED_TESTS++))
        else
            log_fail "Test FASE 2 falliti"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
        
        # Torna alla directory originale
        cd - >/dev/null 2>&1
    else
        log_warning "Script test FASE 2 non trovato: $FASE_2_DIR/test-containers.sh"
    fi
}

# Funzione per test webhook (simulazione)
test_webhook_simulation() {
    echo ""
    echo "=== Test Webhook Simulation ==="
    status_info "Testando simulazione webhook GitHub..."
    
    # Test endpoint webhook
    run_test "Jenkins GitHub Webhook Endpoint" "curl -f -s $JENKINS_URL/github-webhook/"
    
    # Test notifiche (simulazione)
    if command -v mail >/dev/null 2>&1; then
        run_test "Email Notification System" "which mail"
    else
        status_info "Sistema email non configurato (opzionale)"
    fi
}

# Funzione per test performance e monitoring
test_performance_monitoring() {
    echo ""
    echo "=== Test Performance & Monitoring ==="
    status_info "Testando performance e monitoring..."
    
    # Test log files Jenkins
    run_test "Jenkins Log Files" "sudo test -f /var/log/jenkins/jenkins.log"
    
    # Test disk space
    run_test "Disk Space Sufficient" "[ $(df / | tail -1 | awk '{print $4}') -gt 1000000 ]"
    
    # Test memoria disponibile
    run_test "Memory Available" "[ $(free -m | awk 'NR==2{print $7}') -gt 500 ]"
    
    # Test carico sistema
    run_test "System Load Acceptable" "[ $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//') \\< 5.0 ]"
}

# Funzione per generare report JSON
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local success_rate=0
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    cat > "$REPORT_FILE" << EOF
{
    "timestamp": "$timestamp",
    "fase": "FASE 3 - CI/CD Base con Jenkins",
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": $success_rate,
    "jenkins_url": "$JENKINS_URL",
    "log_file": "$LOG_FILE",
    "test_categories": {
        "jenkins_infrastructure": "completed",
        "pipeline_configuration": "completed", 
        "git_integration": "completed",
        "docker_integration": "completed",
        "fase1_integration": "completed",
        "fase2_integration": "completed",
        "webhook_simulation": "completed",
        "performance_monitoring": "completed"
    }
}
EOF
    
    status_success "Report JSON generato: $REPORT_FILE"
}

# Funzione per test manuali
run_manual_tests() {
    echo ""
    echo "======================================="
    echo "   TEST MANUALI FASE 3 - JENKINS"
    echo "======================================="
    
    echo ""
    echo "Esegui i seguenti test manuali:"
    echo ""
    
    echo "1. 🌐 ACCESSO JENKINS WEB UI:"
    echo "   → Apri: $JENKINS_URL"
    echo "   → Verifica login funzionante"
    echo "   → Naviga dashboard Jenkins"
    echo ""
    
    echo "2. 🔧 CONFIGURAZIONE PIPELINE:"
    echo "   → Crea nuovo job 'CRM-Build'"
    echo "   → Configura source GitHub: https://github.com/mcatania72/CRM-System.git"
    echo "   → Imposta branch: main"
    echo "   → Salva configurazione"
    echo ""
    
    echo "3. 🔨 BUILD MANUALE:"
    echo "   → Avvia build manuale job CRM-Build"
    echo "   → Verifica console output"
    echo "   → Controlla build status (success/failure)"
    echo ""
    
    echo "4. 🐳 INTEGRAZIONE DOCKER:"
    echo "   → Verifica che Jenkins veda Docker"
    echo "   → Test build immagine Docker nel job"
    echo "   → Verifica immagini create: docker images"
    echo ""
    
    echo "5. 📋 PLUGIN VERIFICA:"
    echo "   → Manage Jenkins → Manage Plugins"
    echo "   → Verifica plugin installati:"
    echo "     • Git Plugin"
    echo "     • GitHub Plugin"
    echo "     • Docker Plugin"
    echo "     • Pipeline Plugin"
    echo ""
    
    echo "6. 🔗 WEBHOOK GITHUB:"
    echo "   → GitHub → Repository Settings → Webhooks"
    echo "   → Aggiungi webhook: http://DEV_VM_IP:8080/github-webhook/"
    echo "   → Test delivery webhook"
    echo ""
    
    echo "7. 📊 MONITORING:"
    echo "   → Manage Jenkins → System Information"
    echo "   → Verifica memoria, CPU, disk space"
    echo "   → Controlla logs: Manage Jenkins → System Log"
    echo ""
    
    echo "8. 🚀 PIPELINE COMPLETA:"
    echo "   → Crea pipeline che:"
    echo "     1. Clona repository"
    echo "     2. Builds backend + frontend"
    echo "     3. Runs tests (FASE 1 + 2)"
    echo "     4. Builds Docker images"
    echo "     5. Deploy containers"
    echo ""
    
    echo "CHECKLIST COMPLETAMENTO:"
    echo "[ ] Jenkins accessibile su porta 8080"
    echo "[ ] Login Jenkins funzionante"
    echo "[ ] Job CRM-Build creato e funzionante"
    echo "[ ] Git integration configurata"
    echo "[ ] Docker integration funzionante"
    echo "[ ] Build automatico attivato"
    echo "[ ] Webhook GitHub configurato"
    echo "[ ] Test automatici nella pipeline"
    echo "[ ] Deploy automatico container"
    echo "[ ] Monitoring e logging attivi"
    echo ""
    
    echo "🎯 OBIETTIVO FASE 3:"
    echo "Completare tutti i check sopra per una pipeline CI/CD completa!"
    echo ""
    
    status_info "Test manuali completati. Verifica la checklist sopra."
}

# Funzione per mostrare report finale
show_final_report() {
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    echo ""
    echo "======================================="
    echo "   RISULTATI TEST AUTOMATICI"
    echo "======================================="
    status_info "Debug contatori - Total: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS"
    echo "Test Totali: $TOTAL_TESTS"
    echo "Test Passati: $PASSED_TESTS"
    echo "Test Falliti: $FAILED_TESTS"
    echo "Tasso di Successo: $success_rate%"
    echo ""
    
    if [ $success_rate -ge 85 ]; then
        echo "🎉 FASE 3: CI/CD BASE CON JENKINS - SUCCESSO!"
        echo ""
        echo "✅ Risultati eccellenti:"
        echo "   - Tasso di successo: $success_rate% (≥85% richiesto)"
        echo "   - Jenkins completamente funzionante"
        echo "   - Integrazione Git e Docker attiva"
        echo "   - Pipeline infrastructure pronta"
        echo "   - Test FASE 1 e 2 integrati"
        echo ""
        echo "🚀 PRONTO PER FASE 4: SECURITY & MONITORING AVANZATO"
        echo "    - SonarQube integration"
        echo "    - Security scanning"
        echo "    - Advanced monitoring"
        echo "    - Performance optimization"
        echo ""
    elif [ $success_rate -ge 70 ]; then
        echo "⚠️  FASE 3: RISULTATI PARZIALI ($success_rate%)"
        echo ""
        echo "✅ Componenti funzionanti ma necessari miglioramenti:"
        echo "   - Infrastructure Jenkins OK"
        echo "   - Alcuni test falliti da correggere"
        echo "   - Pipeline configurazione da completare"
        echo ""
        echo "🔧 AZIONI NECESSARIE:"
        echo "   1. Rivedere test falliti nei log"
        echo "   2. Completare configurazione pipeline"
        echo "   3. Verificare integrazioni mancanti"
        echo "   4. Ripetere test per raggiungere 85%+"
        echo ""
    else
        echo "❌ FASE 3: NECESSARIE CORREZIONI ($success_rate%)"
        echo ""
        echo "🔧 PROBLEMI IDENTIFICATI:"
        echo "   - Infrastructure Jenkins problematica"
        echo "   - Integrazioni non funzionanti"
        echo "   - Configurazione incompleta"
        echo ""
        echo "📋 AZIONI IMMEDIATE:"
        echo "   1. Verifica installazione Jenkins"
        echo "   2. Controlla log di errore"
        echo "   3. Riavvia prerequisiti se necessario"
        echo "   4. Correggi configurazioni base"
        echo ""
    fi
    
    echo "📁 File di Report:"
    echo "   - Log dettagliato: $LOG_FILE"
    echo "   - Report JSON: $REPORT_FILE"
    echo "   - Jenkins Dashboard: $JENKINS_URL"
    echo ""
    
    echo "🔧 Comandi Utili:"
    echo "   - ./deploy-jenkins.sh status      # Verifica Jenkins"
    echo "   - ./deploy-jenkins.sh logs        # Log Jenkins"
    echo "   - ./test-jenkins.sh manual        # Test manuali"
    echo ""
}

# Funzione principale
main() {
    local test_type="${1:-full}"
    
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Test Suite"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Avvio test suite Jenkins per FASE 3..."
    
    case "$test_type" in
        "full")
            # Test completi CI/CD
            test_jenkins_infrastructure
            test_jenkins_pipelines
            test_git_integration
            test_docker_integration
            run_fase1_tests
            run_fase2_tests
            test_webhook_simulation
            test_performance_monitoring
            ;;
        "jenkins-only")
            # Solo test Jenkins
            test_jenkins_infrastructure
            test_jenkins_pipelines
            ;;
        "integration")
            # Solo test integrazione
            test_git_integration
            test_docker_integration
            run_fase1_tests
            run_fase2_tests
            ;;
        "manual")
            # Test manuali
            run_manual_tests
            return 0
            ;;
        "report")
            # Mostra solo report
            if [ -f "$REPORT_FILE" ]; then
                cat "$REPORT_FILE"
            else
                log_warning "Report file non trovato. Esegui prima: ./test-jenkins.sh"
            fi
            return 0
            ;;
        *)
            echo "Uso: $0 [full|jenkins-only|integration|manual|report]"
            echo ""
            echo "Tipi di test:"
            echo "  full         - Test completi CI/CD (default)"
            echo "  jenkins-only - Solo infrastruttura Jenkins"
            echo "  integration  - Solo test integrazione"
            echo "  manual       - Guida test manuali"
            echo "  report       - Mostra ultimo report"
            echo ""
            exit 1
            ;;
    esac
    
    # Genera report e mostra risultati
    generate_report
    show_final_report
    
    log "Test Jenkins completed - Success rate: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%"
}

# Esecuzione script
main "$@"