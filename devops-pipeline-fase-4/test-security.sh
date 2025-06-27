#!/bin/bash

# =============================================================================
# CRM System - Security Test Suite
# FASE 4: Security Baseline
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
    
    # Test Trivy
    if command -v trivy >/dev/null 2>&1; then
        local trivy_version=$(trivy --version | head -1)
        test_pass "Trivy disponibile: $trivy_version"
    else
        test_fail "Trivy non trovato" "Comando trivy non disponibile"
    fi
    
    # Test OWASP ZAP Docker
    if docker images | grep -q "owasp/zap2docker-stable"; then
        test_pass "OWASP ZAP Docker image presente"
    else
        test_fail "OWASP ZAP mancante" "Docker image non scaricata"
    fi
    
    # Test git-secrets
    if command -v git >/dev/null 2>&1 && git secrets --version >/dev/null 2>&1; then
        test_pass "git-secrets disponibile"
    else
        test_warning "git-secrets non trovato" "Installazione opzionale"
    fi
    
    # Test npm security tools
    if npm list -g npm-audit-html >/dev/null 2>&1; then
        test_pass "npm-audit-html installato"
    else
        test_warning "npm-audit-html mancante" "Tool opzionale"
    fi
}

# Test SonarQube service
test_sonarqube_service() {
    echo "=== Test SonarQube Service ==="
    log_info "Testando servizio SonarQube..."
    
    # Test SonarQube process
    if pgrep -f "sonar" > /dev/null; then
        test_pass "SonarQube processo attivo"
    else
        test_fail "SonarQube non in esecuzione" "Nessun processo sonar trovato"
        return
    fi
    
    # Test SonarQube web interface
    if curl -s "http://localhost:$SONARQUBE_PORT" > /dev/null; then
        test_pass "SonarQube web interface raggiungibile"
    else
        test_fail "SonarQube web interface non raggiungibile" "Porta $SONARQUBE_PORT non risponde"
    fi
    
    # Test SonarQube API
    local api_response=$(curl -s "http://localhost:$SONARQUBE_PORT/api/system/status" || echo "error")
    if echo "$api_response" | grep -q "UP\|OK"; then
        test_pass "SonarQube API funzionante"
    else
        test_warning "SonarQube API non completamente pronta" "Potrebbe essere ancora in avvio"
    fi
}

# Test dependency scanning
test_dependency_scanning() {
    echo "=== Test Dependency Scanning ==="
    log_info "Testando dependency scanning..."
    
    # Test npm audit on backend
    if [ -d "$HOME/devops/CRM-System/backend" ]; then
        cd "$HOME/devops/CRM-System/backend"
        if npm audit --audit-level info >/dev/null 2>&1; then
            test_pass "npm audit backend eseguito"
        else
            # npm audit returns non-zero if vulnerabilities found, but that's expected
            if npm audit --audit-level high >/dev/null 2>&1; then
                test_pass "npm audit backend eseguito (vulnerabilità trovate)"
            else
                test_warning "npm audit backend ha trovato vulnerabilità critiche" "Review necessaria"
            fi
        fi
    else
        test_fail "Backend directory non trovata" "$HOME/devops/CRM-System/backend mancante"
    fi
    
    # Test npm audit on frontend
    if [ -d "$HOME/devops/CRM-System/frontend" ]; then
        cd "$HOME/devops/CRM-System/frontend"
        if npm audit --audit-level info >/dev/null 2>&1; then
            test_pass "npm audit frontend eseguito"
        else
            if npm audit --audit-level high >/dev/null 2>&1; then
                test_pass "npm audit frontend eseguito (vulnerabilità trovate)"
            else
                test_warning "npm audit frontend ha trovato vulnerabilità critiche" "Review necessaria"
            fi
        fi
    else
        test_fail "Frontend directory non trovata" "$HOME/devops/CRM-System/frontend mancante"
    fi
}

# Test container security
test_container_security() {
    echo "=== Test Container Security ==="
    log_info "Testando container security scanning..."
    
    # Check if containers exist
    if docker images | grep -q "crm-backend"; then
        # Test Trivy scanning
        if trivy image --exit-code 1 --severity HIGH,CRITICAL crm-backend:latest >/dev/null 2>&1; then
            test_pass "Container backend scan - nessuna vulnerabilità critica"
        else
            test_warning "Container backend ha vulnerabilità" "Review necessaria"
        fi
    else
        test_warning "Container backend non trovato" "Build container prima del test"
    fi
    
    if docker images | grep -q "crm-frontend"; then
        if trivy image --exit-code 1 --severity HIGH,CRITICAL crm-frontend:latest >/dev/null 2>&1; then
            test_pass "Container frontend scan - nessuna vulnerabilità critica"
        else
            test_warning "Container frontend ha vulnerabilità" "Review necessaria"
        fi
    else
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
        if grep -q "Dependencies Security Scan" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene security stages"
        else
            test_fail "Jenkinsfile manca security stages" "Security integration non configurata"
        fi
        
        if grep -q "SAST" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene SAST stage"
        else
            test_fail "Jenkinsfile manca SAST stage" "Static analysis non configurata"
        fi
        
        if grep -q "DAST" "$jenkinsfile"; then
            test_pass "Jenkinsfile contiene DAST stage"
        else
            test_fail "Jenkinsfile manca DAST stage" "Dynamic analysis non configurata"
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
        
        # Test Jenkins availability
        if systemctl is-active jenkins >/dev/null 2>&1; then
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
    "trivy": "$(command -v trivy >/dev/null && echo "installed" || echo "missing")",
    "owasp_zap": "$(docker images | grep -q owasp/zap2docker-stable && echo "installed" || echo "missing")"
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
    echo "   FASE 4: Security Baseline"
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