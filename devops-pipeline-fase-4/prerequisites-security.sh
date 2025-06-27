#!/bin/bash

# =============================================================================
# CRM System - Security Prerequisites Script
# FASE 4: Security Baseline
# =============================================================================

set -euo pipefail

# Configuration
LOG_FILE="$HOME/prerequisites-security.log"
SOPNARQUBE_VERSION="9.9.3.79811"
TRIVY_VERSION="0.48.3"

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Questo script non deve essere eseguito come root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisite() {
    local cmd="$1"
    local name="$2"
    local install_cmd="$3"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=$(eval "$cmd --version 2>/dev/null | head -1 || echo 'unknown'")
        log_success "$name già installato: $version"
        return 0
    else
        log_info "$name non trovato, installazione in corso..."
        eval "$install_cmd"
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "$name installato con successo"
            return 0
        else
            log_error "Fallita installazione di $name"
            return 1
        fi
    fi
}

# Install SonarQube Community Edition
install_sonarqube() {
    log_info "Installazione SonarQube Community Edition..."
    
    # Check if already installed
    if [ -d "$HOME/sonarqube" ]; then
        log_success "SonarQube già installato in $HOME/sonarqube"
        return 0
    fi
    
    # Download and install
    cd "$HOME"
    wget -q "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip" -O sonarqube.zip
    unzip -q sonarqube.zip
    mv "sonarqube-${SONARQUBE_VERSION}" sonarqube
    rm sonarqube.zip
    
    # Set permissions
    chmod +x sonarqube/bin/linux-x86-64/sonar.sh
    
    log_success "SonarQube installato in $HOME/sonarqube"
}

# Install Trivy
install_trivy() {
    log_info "Installazione Trivy scanner..."
    
    # Download and install
    wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -O /tmp/trivy.tar.gz
    tar -xzf /tmp/trivy.tar.gz -C /tmp
    sudo mv /tmp/trivy /usr/local/bin/
    rm /tmp/trivy.tar.gz
    
    log_success "Trivy installato in /usr/local/bin/trivy"
}

# Install OWASP ZAP
install_owasp_zap() {
    log_info "Installazione OWASP ZAP..."
    
    # Check if already installed via Docker
    if docker images | grep -q "owasp/zap2docker-stable"; then
        log_success "OWASP ZAP Docker image già presente"
        return 0
    fi
    
    # Pull OWASP ZAP Docker image
    docker pull owasp/zap2docker-stable:latest
    log_success "OWASP ZAP Docker image scaricata"
}

# Install security tools for Node.js
install_nodejs_security() {
    log_info "Installazione tool security Node.js..."
    
    # Install security linting tools globally
    npm install -g npm-audit-html retire eslint-plugin-security
    
    log_success "Tool security Node.js installati"
}

# Install git-secrets
install_git_secrets() {
    log_info "Installazione git-secrets..."
    
    if [ -d "$HOME/git-secrets" ]; then
        log_success "git-secrets già installato"
        return 0
    fi
    
    # Clone and install
    cd "$HOME"
    git clone https://github.com/awslabs/git-secrets.git
    cd git-secrets
    sudo make install
    
    log_success "git-secrets installato"
}

# Main execution
main() {
    echo "======================================="
    echo "   CRM System - Security Prerequisites"
    echo "   FASE 4: Security Baseline"
    echo "======================================="
    log_info "Avvio verifica e installazione prerequisiti security..."
    
    # Basic checks
    check_root
    
    # Check system prerequisites
    log_info "Verifica prerequisiti di sistema..."
    check_prerequisite "curl" "cURL" "sudo apt-get update && sudo apt-get install -y curl"
    check_prerequisite "wget" "wget" "sudo apt-get install -y wget"
    check_prerequisite "unzip" "unzip" "sudo apt-get install -y unzip"
    check_prerequisite "docker" "Docker" "echo 'Docker deve essere installato manualmente'"
    check_prerequisite "npm" "Node.js/npm" "echo 'Node.js deve essere installato manualmente'"
    check_prerequisite "java" "Java" "sudo apt-get install -y openjdk-17-jdk"
    
    # Install security tools
    log_info "Installazione security tools specializzati..."
    install_sonarqube
    install_trivy
    install_owasp_zap
    install_nodejs_security
    install_git_secrets
    
    # Create security directories
    log_info "Creazione directory security..."
    mkdir -p "$HOME/security-reports"/{sonarqube,trivy,zap,npm-audit}
    mkdir -p "$HOME/security-configs"
    
    # Summary
    echo ""
    echo "======================================="
    echo "   VERIFICA PREREQUISITI COMPLETATA"
    echo "======================================="
    
    # Check versions
    echo "🔒 Security Tools installati:"
    echo "- SonarQube: $(ls -d $HOME/sonarqube 2>/dev/null && echo 'Installato' || echo 'Non trovato')"
    echo "- Trivy: $(trivy --version 2>/dev/null | head -1 || echo 'Non trovato')"
    echo "- OWASP ZAP: $(docker images | grep owasp/zap2docker-stable | wc -l) image(s)"
    echo "- git-secrets: $(git secrets --version 2>/dev/null || echo 'Non trovato')"
    echo "- npm-audit-html: $(npm list -g npm-audit-html 2>/dev/null | grep npm-audit-html || echo 'Non trovato')"
    
    echo ""
    echo "📊 Sistema pronto per security scanning:"
    echo "- Dependency scanning: npm audit + Trivy"
    echo "- Static analysis: SonarQube"
    echo "- Dynamic testing: OWASP ZAP"
    echo "- Secret detection: git-secrets"
    echo "- Reports: $HOME/security-reports/"
    
    log_success "✅ Tutti i prerequisiti per FASE 4 sono soddisfatti!"
    
    echo ""
    echo "🚀 Prossimi passi:"
    echo "1. ./deploy-security.sh start    # Deploy security pipeline"
    echo "2. ./test-security.sh            # Test security compliance"
}

# Execute main function
main "$@"