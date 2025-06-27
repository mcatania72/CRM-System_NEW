#!/bin/bash

# =============================================================================
# CRM System - Security Prerequisites Script
# FASE 4: Security Baseline
# =============================================================================

set -euo pipefail

# Configuration
LOG_FILE="$HOME/prerequisites-security.log"
SONARQUBE_VERSION="9.9.3.79811"
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

# Install SonarQube Community Edition with robust error handling
install_sonarqube() {
    log_info "Installazione SonarQube Community Edition..."
    
    # Check if already installed
    if [ -d "$HOME/sonarqube" ] && [ -x "$HOME/sonarqube/bin/linux-x86-64/sonar.sh" ]; then
        log_success "SonarQube già installato in $HOME/sonarqube"
        return 0
    fi
    
    # Clean any partial installation
    if [ -d "$HOME/sonarqube" ]; then
        log_info "Rimozione installazione SonarQube parziale..."
        rm -rf "$HOME/sonarqube"
    fi
    
    # Remove any existing zip files
    rm -f "$HOME/sonarqube*.zip" 2>/dev/null || true
    
    # Download with progress and error handling
    log_info "Download SonarQube ${SONARQUBE_VERSION}..."
    cd "$HOME"
    
    local download_url="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip"
    
    if ! wget --progress=dot:giga --timeout=300 --tries=3 "$download_url" -O sonarqube.zip; then
        log_error "Fallito download di SonarQube da $download_url"
        return 1
    fi
    
    # Verify download
    if [ ! -f "sonarqube.zip" ] || [ ! -s "sonarqube.zip" ]; then
        log_error "File SonarQube zip non valido o vuoto"
        rm -f sonarqube.zip
        return 1
    fi
    
    local zip_size=$(stat -c%s sonarqube.zip 2>/dev/null || echo "0")
    log_info "SonarQube zip scaricato: ${zip_size} bytes"
    
    # Extract with error handling
    log_info "Estrazione SonarQube (può richiedere 1-2 minuti)..."
    if ! unzip -q sonarqube.zip; then
        log_error "Fallita estrazione di SonarQube"
        rm -f sonarqube.zip
        return 1
    fi
    
    # Verify extraction
    if [ ! -d "sonarqube-${SONARQUBE_VERSION}" ]; then
        log_error "Directory SonarQube non trovata dopo estrazione"
        rm -f sonarqube.zip
        return 1
    fi
    
    # Rename directory
    if ! mv "sonarqube-${SONARQUBE_VERSION}" sonarqube; then
        log_error "Fallita rinomina directory SonarQube"
        return 1
    fi
    
    # Clean zip file
    rm -f sonarqube.zip
    
    # Set permissions
    if [ -f "sonarqube/bin/linux-x86-64/sonar.sh" ]; then
        chmod +x sonarqube/bin/linux-x86-64/sonar.sh
        log_success "SonarQube installato con successo in $HOME/sonarqube"
    else
        log_error "File sonar.sh non trovato dopo installazione"
        return 1
    fi
    
    return 0
}

# Install Trivy with improved error handling
install_trivy() {
    log_info "Installazione Trivy scanner..."
    
    # Check if already installed
    if command -v trivy >/dev/null 2>&1; then
        log_success "Trivy già installato: $(trivy --version | head -1)"
        return 0
    fi
    
    # Download and install with error handling
    local trivy_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
    
    log_info "Download Trivy ${TRIVY_VERSION}..."
    if ! wget -q --timeout=120 --tries=3 "$trivy_url" -O /tmp/trivy.tar.gz; then
        log_error "Fallito download di Trivy"
        return 1
    fi
    
    if ! tar -xzf /tmp/trivy.tar.gz -C /tmp; then
        log_error "Fallita estrazione di Trivy"
        rm -f /tmp/trivy.tar.gz
        return 1
    fi
    
    if ! sudo mv /tmp/trivy /usr/local/bin/; then
        log_error "Fallita installazione di Trivy in /usr/local/bin/"
        rm -f /tmp/trivy.tar.gz
        return 1
    fi
    
    rm -f /tmp/trivy.tar.gz
    
    # Verify installation
    if command -v trivy >/dev/null 2>&1; then
        log_success "Trivy installato: $(trivy --version | head -1)"
    else
        log_error "Trivy non funziona dopo installazione"
        return 1
    fi
}

# Install OWASP ZAP
install_owasp_zap() {
    log_info "Installazione OWASP ZAP..."
    
    # Check if already installed via Docker
    if docker images | grep -q "owasp/zap2docker-stable"; then
        log_success "OWASP ZAP Docker image già presente"
        return 0
    fi
    
    # Pull OWASP ZAP Docker image with timeout
    log_info "Download OWASP ZAP Docker image..."
    if ! timeout 300 docker pull owasp/zap2docker-stable:latest; then
        log_error "Fallito download OWASP ZAP Docker image"
        return 1
    fi
    
    log_success "OWASP ZAP Docker image scaricata"
}

# Install security tools for Node.js
install_nodejs_security() {
    log_info "Installazione tool security Node.js..."
    
    # Check if tools are already installed
    if npm list -g npm-audit-html >/dev/null 2>&1; then
        log_success "Security tools Node.js già installati"
        return 0
    fi
    
    # Install security linting tools globally with error handling
    log_info "Installazione npm security tools globali..."
    if ! npm install -g npm-audit-html retire eslint-plugin-security license-checker; then
        log_error "Fallita installazione npm security tools"
        return 1
    fi
    
    log_success "Tool security Node.js installati"
}

# Install git-secrets
install_git_secrets() {
    log_info "Installazione git-secrets..."
    
    # Check if already installed
    if command -v git >/dev/null 2>&1 && git secrets --version >/dev/null 2>&1; then
        log_success "git-secrets già installato"
        return 0
    fi
    
    # Clone and install with error handling
    if [ ! -d "$HOME/git-secrets" ]; then
        log_info "Cloning git-secrets repository..."
        cd "$HOME"
        if ! git clone https://github.com/awslabs/git-secrets.git; then
            log_error "Fallito clone di git-secrets repository"
            return 1
        fi
    fi
    
    cd "$HOME/git-secrets"
    if ! sudo make install; then
        log_error "Fallita installazione di git-secrets"
        return 1
    fi
    
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
    
    # Install security tools with robust error handling
    log_info "Installazione security tools specializzati..."
    
    local install_failed=false
    
    # Install each tool and track failures
    install_sonarqube || install_failed=true
    install_trivy || install_failed=true
    install_owasp_zap || install_failed=true
    install_nodejs_security || install_failed=true
    install_git_secrets || true  # Optional, don't fail on this
    
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
    echo "- SonarQube: $([ -d $HOME/sonarqube ] && echo 'Installato' || echo 'MANCANTE')"
    echo "- Trivy: $(trivy --version 2>/dev/null | head -1 || echo 'MANCANTE')"
    echo "- OWASP ZAP: $(docker images | grep owasp/zap2docker-stable | wc -l) image(s)"
    echo "- git-secrets: $(git secrets --version 2>/dev/null || echo 'Non installato')"
    echo "- npm-audit-html: $(npm list -g npm-audit-html 2>/dev/null | grep npm-audit-html >/dev/null && echo 'Installato' || echo 'Non installato')"
    echo "- license-checker: $(npm list -g license-checker 2>/dev/null | grep license-checker >/dev/null && echo 'Installato' || echo 'Non installato')"
    
    echo ""
    echo "📊 Sistema pronto per security scanning:"
    echo "- Dependency scanning: npm audit + Trivy"
    echo "- Static analysis: SonarQube"
    echo "- Dynamic testing: OWASP ZAP"
    echo "- Secret detection: git-secrets"
    echo "- License compliance: license-checker"
    echo "- Reports: $HOME/security-reports/"
    
    if [ "$install_failed" = "false" ]; then
        log_success "✅ Tutti i prerequisiti per FASE 4 sono soddisfatti!"
        echo ""
        echo "🚀 Prossimi passi:"
        echo "1. ./deploy-security.sh start    # Deploy security pipeline"
        echo "2. ./test-security.sh            # Test security compliance"
        return 0
    else
        log_error "❌ Alcuni prerequisiti hanno avuto problemi di installazione"
        echo ""
        echo "🔧 Risoluzione problemi:"
        echo "1. Controlla il log: $LOG_FILE"
        echo "2. Riprova: ./prerequisites-security.sh"
        echo "3. Se persistono errori, installa manualmente i tool mancanti"
        return 1
    fi
}

# Execute main function
main "$@"