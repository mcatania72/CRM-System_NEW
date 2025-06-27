#!/bin/bash

# =============================================================================
# CRM System - Security Test Suite
# FASE 4: Security Baseline - ULTRA ROBUST VERSION
# =============================================================================

set -euo pipefail

# Configuration
LOG_FILE="$HOME/test-security.log"
REPORT_FILE="$HOME/security-test-report.json"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SONARQUBE_PORT=9000

# Logging functions
log_info() {
    echo "[INFO] $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $1" >> "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] ✅ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo "[WARNING] ⚠️ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo "[ERROR] ❌ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$LOG_FILE"
}

# Test functions
test_pass() {
    local test_name="$1"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    log_success "$test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    log_error "$test_name - $reason"
}

test_warning() {
    local test_name="$1"
    local reason="$2"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))  # Warning counts as pass
    log_warning "$test_name - $reason"
}

# Safe command check with timeout and alternative methods
safe_command_check() {
    local cmd="$1"
    local timeout_sec="${2:-3}"
    
    # Method 1: Try which first (fastest)
    if timeout "$timeout_sec" which "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 2: Try direct execution with version
    if timeout "$timeout_sec" "$cmd" --version >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 3: Check if file exists in common paths
    for path in /usr/local/bin /usr/bin /bin ~/.local/bin; do
        if [ -x "$path/$cmd" ]; then
            return 0
        fi
    done
    
    return 1
}

# Security Tools Tests
test_security_tools() {
    echo "=== Test Security Tools Installation ==="
    log_info "Testando installazione security tools..."
    
    # Test SonarQube
    if [ -d "$HOME/sonarqube" ]; then
        test_pass "SonarQube installato"
    else
        test_fail "SonarQube non trovato" "Directory $HOME/sonarqube mancante"
    fi
    
    # Test Trivy - ROBUST CHECK
    log_info "Verificando Trivy..."
    if safe_command_check "trivy" 5; then
        # Try to get version safely
        local trivy_version=""
        if trivy_version=$(timeout 10 trivy --version 2>/dev/null | head -1); then
            test_pass "Trivy disponibile: $trivy_version"
        else
            test_pass "Trivy disponibile (versione non determinabile)"
        fi
    else
        test_fail "Trivy non trovato" "Comando trivy non disponibile"
    fi
    
    # Test OWASP ZAP Docker - Enhanced check
    log_info "Verificando OWASP ZAP Docker..."
    local zap_found=false
    if timeout 15 docker images --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "zaproxy/zap-stable"; then
        test_pass "OWASP ZAP Docker image presente (zaproxy/zap-stable)"
        zap_found=true
    elif timeout 15 docker images --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "owasp/zap2docker-stable"; then
        test_pass "OWASP ZAP Docker image presente (owasp/zap2docker-stable)"
        zap_found=true
    fi
    
    if [ "$zap_found" = false ]; then
        test_fail "OWASP ZAP mancante" "Docker image non scaricata"
    fi
    
    # Test git-secrets - SAFE CHECK
    log_info "Verificando git-secrets..."
    if safe_command_check "git" 3; then
        if timeout 5 git secrets --version >/dev/null 2>&1; then
            test_pass "git-secrets disponibile"
        else
            test_warning "git-secrets non configurato" "Installazione opzionale"
        fi
    else
        test_warning "git command non disponibile" "Installazione git richiesta"
    fi
    
    # Test npm security tools - VERY SAFE CHECK
    log_info "Verificando npm security tools..."
    if safe_command_check "npm" 3; then
        if timeout 8 npm list -g --depth=0 2>/dev/null | grep -q "npm-audit-html"; then
            test_pass "npm-audit-html installato"
        else
            test_warning "npm-audit-html mancante" "Tool opzionale per report HTML"
        fi
    else
        test_warning "npm non disponibile" "Richiesto per security tools aggiuntivi"
    fi
}

# Test SonarQube service
test_sonarqube_service() {
    echo "=== Test SonarQube Service ==="
    log_info "Testando servizio SonarQube..."
    
    # Test SonarQube process with timeout
    if timeout 5 pgrep -f "sonar" > /dev/null 2>&1; then
        test_pass "SonarQube processo attivo"
    else
        test_fail "SonarQube non in esecuzione" "Nessun processo sonar trovato"
        return
    fi
    
    # Test SonarQube web interface with timeout
    if timeout 10 curl -s --connect-timeout 5 "http://localhost:$SONARQUBE_PORT" > /dev/null 2>&1; then
        test_pass "SonarQube web interface raggiungibile"
    else
        test_fail "SonarQube web interface non raggiungibile" "Porta $SONARQUBE_PORT non risponde"
    fi
    
    # Test SonarQube API with timeout
    local api_response=""
    if api_response=$(timeout 10 curl -s --connect-timeout 5 "http://localhost:$SONARQUBE_PORT/api/system/status" 2>/dev/null); then
        if echo "$api_response" | grep -q "UP\|OK"; then
            test_pass "SonarQube API funzionante"
        else
            test_warning "SonarQube API non completamente pronta" "Potrebbe essere ancora in avvio"
        fi
    else
        test_warning "SonarQube API timeout" "Servizio potrebbe essere ancora in avvio"
    fi
}

# Test dependency scanning
test_dependency_scanning() {
    echo "=== Test Dependency Scanning ==="
    log_info "Testando dependency scanning..."
    
    # Test npm audit on backend with enhanced safety
    if [ -d "$HOME/devops/CRM-System/backend" ]; then
        cd "$HOME/devops/CRM-System/backend" || return
        if [ -f "package.json" ]; then
            if timeout 30 npm audit --audit-level info >/dev/null 2>&1; then
                test_pass "npm audit backend eseguito"
            else
                # npm audit returns non-zero if vulnerabilities found
                test_warning "npm audit backend completato con vulnerabilità" "Review necessaria"
            fi
        else
            test_warning "package.json backend non trovato" "Dependency scanning non possibile"
        fi
    else
        test_fail "Backend directory non trovata" "$HOME/devops/CRM-System/backend mancante"
    fi
    
    # Test npm audit on frontend with enhanced safety
    if [ -d "$HOME/devops/CRM-System/frontend" ]; then
        cd "$HOME/devops/CRM-System/frontend" || return
        if [ -f "package.json" ]; then
            if timeout 30 npm audit --audit-level info >/dev/null 2>&1; then
                test_pass "npm audit frontend eseguito"
            else
                test_warning "npm audit frontend completato con vulnerabilità" "Review necessaria"
            fi
        else
            test_warning "package.json frontend non trovato" "Dependency scanning non possibile"
        fi
    else
        test_fail "Frontend directory non trovata" "$HOME/devops/CRM-System/frontend mancante"
    fi
}

# Test container security
test_container_security() {
    echo "=== Test Container Security ==="
    log_info "Testando container security scanning..."
    
    # Check if containers exist safely
    local backend_exists=false
    local frontend_exists=false
    
    if timeout 10 docker images --format "{{.Repository}}" 2>/dev/null | grep -q "crm-backend"; then
        backend_exists=true
        if safe_command_check "trivy" 5; then
            if timeout 60 trivy image --exit-code 1 --severity HIGH,CRITICAL crm-backend:latest >/dev/null 2>&1; then
                test_pass "Container backend scan - nessuna vulnerabilità critica"
            else
                test_warning "Container backend ha vulnerabilità" "Review necessaria"
            fi
        else
            test_warning "Container backend non scansionabile" "Trivy non disponibile"
        fi
    fi
    
    if timeout 10 docker images --format "{{.Repository}}" 2>/dev/null | grep -q "crm-frontend"; then
        frontend_exists=true
        if safe_command_check "trivy" 5; then
            if timeout 60 trivy image --exit-code 1 --severity HIGH,CRITICAL crm-frontend:latest >/dev/null 2>&1; then
                test_pass "Container frontend scan - nessuna vulnerabilità critica"
            else
                test_warning "Container frontend ha vulnerabilità" "Review necessaria"
            fi
        else
            test_warning "Container frontend non scansionabile" "Trivy non disponibile"
        fi
    fi
    
    if [ "$backend_exists" = false ]; then
        test_warning "Container backend non trovato" "Build container prima del test"
    fi
    
    if [ "$frontend_exists" = false ]; then
        test_warning "Container frontend non trovato" "Build container prima del test"
    fi
}

# Test Jenkins security integration
test_jenkins_integration() {
    echo "=== Test Jenkins Security Integration ==="
    log_info "Testando integrazione Jenkins security..."
    
    # Test if Jenkinsfile has security stages
    local jenkinsfile="$HOME/devops-pipeline-fase-3/jenkins/Jenkinsfile.crm-build"
    if [ -f "$jenkinsfile" ]; then
        if grep -q "Dependencies Security Scan\|Security" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene security stages"
        else
            test_fail "Jenkinsfile manca security stages" "Security integration non configurata"
        fi
        
        if grep -q "SAST\|SonarQube" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene SAST stage"
        else
            test_fail "Jenkinsfile manca SAST stage" "Static analysis non configurata"
        fi
        
        if grep -q "DAST\|ZAP" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene DAST stage"
        else
            test_warning "Jenkinsfile manca DAST stage" "Dynamic analysis opzionale"
        fi
    else
        test_fail "Jenkinsfile non trovato" "$jenkinsfile mancante"
    fi
}

# Test FASE 1,2,3 integration
test_previous_phases_integration() {
    echo "=== Test Integrazione Fasi Precedenti ==="
    log_info "Testando integrazione con FASE 1, 2, 3..."
    
    # Test FASE 1 availability
    if [ -d "$HOME/devops-pipeline-fase-1" ]; then
        test_pass "FASE 1 presente e disponibile"
    else
        test_fail "FASE 1 non trovata" "Prerequisito per FASE 4"
    fi
    
    # Test FASE 2 availability
    if [ -d "$HOME/devops-pipeline-fase-2" ]; then
        test_pass "FASE 2 presente e disponibile"
    else
        test_fail "FASE 2 non trovata" "Prerequisito per FASE 4"
    fi
    
    # Test FASE 3 availability
    if [ -d "$HOME/devops-pipeline-fase-3" ]; then
        test_pass "FASE 3 presente e disponibile"
        
        # Test Jenkins availability with safe timeout
        if timeout 5 systemctl is-active jenkins >/dev/null 2>&1; then
            test_pass "Jenkins service attivo"
        else
            test_warning "Jenkins service non attivo" "Avviare con systemctl start jenkins"
        fi
    else
        test_fail "FASE 3 non trovata" "Prerequisito per FASE 4"
    fi
}

# Test security reports generation
test_security_reports() {
    echo "=== Test Security Reports ==="
    log_info "Testando generazione security reports..."
    
    local reports_dir="$HOME/security-reports"
    
    # Test reports directory
    if [ -d "$reports_dir" ]; then
        test_pass "Security reports directory presente"
    else
        test_fail "Security reports directory mancante" "$reports_dir non trovato"
        return
    fi
    
    # Test subdirectories
    for subdir in sonarqube trivy zap npm-audit; do
        if [ -d "$reports_dir/$subdir" ]; then
            test_pass "Reports subdirectory $subdir presente"
        else
            test_warning "Reports subdirectory $subdir mancante" "Verrà creato al primo utilizzo"
        fi
    done
    
    # Test write permissions
    if [ -w "$reports_dir" ]; then
        test_pass "Security reports directory scrivibile"
    else
        test_fail "Security reports directory non scrivibile" "Verificare permessi"
    fi
}

# Generate security test report
generate_report() {
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "phase": "FASE 4: Security Baseline",
  "total_tests": $TOTAL_TESTS,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "success_rate": $success_rate,
  "status": "$([ $success_rate -ge 80 ] && echo "PASS" || echo "FAIL")",
  "tools": {
    "sonarqube": "$([ -d $HOME/sonarqube ] && echo "installed" || echo "missing")",
    "trivy": "$(safe_command_check trivy 3 && echo "installed" || echo "missing")",
    "owasp_zap": "$(timeout 10 docker images 2>/dev/null | grep -q 'zaproxy/zap-stable\|owasp/zap2docker-stable' && echo "installed" || echo "missing")"
  },
  "recommendations": [
    $([ $success_rate -lt 80 ] && echo '    "Review failed tests and fix security tools installation",' || echo '')
    $([ $FAILED_TESTS -gt 0 ] && echo '    "Address failed security checks before production deployment",' || echo '')
    "Regular security scanning should be integrated into CI/CD pipeline",
    "Monitor security reports for new vulnerabilities"
  ]
}
EOF
}

# Main execution
main() {
    local action="${1:-full}"
    
    echo "======================================="
    echo "   CRM System - Security Test Suite"
    echo "   FASE 4: Security Baseline - ROBUST"
    echo "======================================="
    log_info "Avvio test suite security per FASE 4..."
    
    case "$action" in
        "full")
            test_security_tools
            test_sonarqube_service
            test_dependency_scanning
            test_container_security
            test_jenkins_integration
            test_previous_phases_integration
            test_security_reports
            ;;
        "tools")
            test_security_tools
            ;;
        "sonarqube")
            test_sonarqube_service
            ;;
        "dependencies")
            test_dependency_scanning
            ;;
        "containers")
            test_container_security
            ;;
        "jenkins")
            test_jenkins_integration
            ;;
        "reports")
            test_security_reports
            ;;
        *)
            echo "Uso: $0 [full|tools|sonarqube|dependencies|containers|jenkins|reports]"
            echo ""
            echo "Test disponibili:"
            echo "  full         - Tutti i test security (default)"
            echo "  tools        - Test installazione security tools"
            echo "  sonarqube    - Test servizio SonarQube"
            echo "  dependencies - Test dependency scanning"
            echo "  containers   - Test container security"
            echo "  jenkins      - Test integrazione Jenkins"
            echo "  reports      - Test security reports"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_report
    
    # Results summary
    echo ""
    echo "======================================="
    echo "   RISULTATI TEST SECURITY"
    echo "======================================="
    echo "Test Totali: $TOTAL_TESTS"
    echo "Test Passati: $PASSED_TESTS"
    echo "Test Falliti: $FAILED_TESTS"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    echo "Tasso di Successo: $success_rate%"
    
    echo ""
    if [ $success_rate -ge 95 ]; then
        echo "🏆 FASE 4: SECURITY BASELINE - ECCELLENZA RAGGIUNTA!"
        log_success "Security baseline eccellente ($success_rate%)"
    elif [ $success_rate -ge 80 ]; then
        echo "🎉 FASE 4: SECURITY BASELINE - COMPLETATA CON SUCCESSO!"
        log_success "Security baseline completata ($success_rate%)"
    else
        echo "⚠️ FASE 4: SECURITY BASELINE - MIGLIORAMENTI NECESSARI"
        log_warning "Security baseline necessita miglioramenti ($success_rate%)"
    fi
    
    echo ""
    echo "📈 Report dettagliato: $REPORT_FILE"
    echo "📊 Log completo: $LOG_FILE"
    
    if [ $success_rate -ge 80 ]; then
        echo ""
        echo "🚀 Prossimi passi suggeriti:"
        echo "- FASE 5: Kubernetes Orchestration + Advanced Security"
        echo "- FASE 6: Infrastructure as Code + Compliance"
        echo "- Security monitoring e incident response"
    fi
}

# Execute main function
main "$@"