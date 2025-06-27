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

# Install OWASP ZAP with correct Docker image name
install_owasp_zap() {
    log_info "Installazione OWASP ZAP..."
    
    # Check multiple possible image names (Docker repository changed)
    local zap_images=("zaproxy/zap-stable" "owasp/zap2docker-stable" "zaproxy/zap-weekly")
    local zap_found=false
    
    for image in "${zap_images[@]}"; do
        if docker images | grep -q "$image"; then
            log_success "OWASP ZAP Docker image già presente: $image"
            zap_found=true
            break
        fi
    done
    
    if [ "$zap_found" = "true" ]; then
        return 0
    fi
    
    # Try to pull the correct ZAP image (new repository name)
    log_info "Download OWASP ZAP Docker image (nuovo repository)..."
    
    for image in "${zap_images[@]}"; do
        log_info "Tentativo download: $image"
        if timeout 300 docker pull "$image:latest" 2>/dev/null; then
            log_success "OWASP ZAP Docker image scaricata: $image"
            return 0
        fi
    done
    
    log_error "Fallito download di tutte le varianti OWASP ZAP"
    log_warning "OWASP ZAP può essere installato manualmente con: docker pull zaproxy/zap-stable"
    return 1
}

# Install security tools for Node.js with proper permissions
install_nodejs_security() {
    log_info "Installazione tool security Node.js..."
    
    # Check if tools are already installed
    if npm list -g npm-audit-html >/dev/null 2>&1; then
        log_success "Security tools Node.js già installati"
        return 0
    fi
    
    # Setup npm global directory to avoid permission issues
    log_info "Configurazione npm global directory..."
    local npm_global_dir="$HOME/.npm-global"
    
    # Create npm global directory
    mkdir -p "$npm_global_dir"
    
    # Configure npm to use the local directory
    npm config set prefix "$npm_global_dir"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$npm_global_dir/bin"; then
        export PATH="$npm_global_dir/bin:$PATH"
        
        # Add to .bashrc for persistence
        if ! grep -q "npm-global/bin" "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
            log_info "Aggiunto npm global path a .bashrc"
        fi
    fi
    
    # Install security linting tools globally with proper permissions
    log_info "Installazione npm security tools in directory locale..."
    if ! npm install -g npm-audit-html retire eslint-plugin-security license-checker; then
        log_error "Fallita installazione npm security tools"
        return 1
    fi
    
    log_success "Tool security Node.js installati in $npm_global_dir"
    log_info "Riavvia il terminale o esegui: source ~/.bashrc per aggiornare PATH"
}

# Install git-secrets
install_git_secrets() {
    log_info "Installazione git-secrets..."
    
    # Check if already installed
    if command -v git >/dev/null 2>&1 && git secrets --version >/dev/null 2>&1; then
        log_success "git-secrets già installato"
        return 0
    fi
    
    # Install build dependencies
    log_info "Installazione dipendenze build per git-secrets..."
    sudo apt-get update -qq
    sudo apt-get install -y build-essential make
    
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
    local warnings=0
    
    # Install each tool and track failures
    install_sonarqube || install_failed=true
    install_trivy || install_failed=true
    install_owasp_zap || { warnings=$((warnings + 1)); log_warning "OWASP ZAP installazione fallita - non bloccante"; }
    install_nodejs_security || { warnings=$((warnings + 1)); log_warning "NPM Security tools installazione fallita - non bloccante"; }
    install_git_secrets || { warnings=$((warnings + 1)); log_warning "git-secrets installazione fallita - non bloccante"; }
    
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
    echo "- SonarQube: $([ -d $HOME/sonarqube ] && echo '✅ Installato' || echo '❌ MANCANTE')"
    echo "- Trivy: $(trivy --version 2>/dev/null | head -1 | sed 's/Version: /✅ /' || echo '❌ MANCANTE')"
    echo "- OWASP ZAP: $(docker images | grep -E 'zap|zaproxy' | wc -l) image(s) $([ $(docker images | grep -E 'zap|zaproxy' | wc -l) -gt 0 ] && echo '✅' || echo '⚠️')"
    echo "- git-secrets: $(git secrets --version 2>/dev/null | sed 's/^/✅ /' || echo '⚠️ Non installato')"
    echo "- npm-audit-html: $(npm list -g npm-audit-html 2>/dev/null | grep npm-audit-html >/dev/null && echo '✅ Installato' || echo '⚠️ Non installato')"
    echo "- license-checker: $(npm list -g license-checker 2>/dev/null | grep license-checker >/dev/null && echo '✅ Installato' || echo '⚠️ Non installato')"
    
    echo ""
    echo "📊 Sistema pronto per security scanning:"
    echo "- Dependency scanning: npm audit + Trivy"
    echo "- Static analysis: SonarQube"
    echo "- Dynamic testing: OWASP ZAP"
    echo "- Secret detection: git-secrets"
    echo "- License compliance: license-checker"
    echo "- Reports: $HOME/security-reports/"
    
    if [ "$install_failed" = "false" ]; then
        if [ $warnings -eq 0 ]; then
            log_success "✅ Tutti i prerequisiti per FASE 4 sono soddisfatti!"
        else
            log_success "✅ Prerequisiti essenziali per FASE 4 soddisfatti (con $warnings warning)"
        fi
        echo ""
        echo "🚀 Prossimi passi:"
        echo "1. ./deploy-security.sh start    # Deploy security pipeline"
        echo "2. ./test-security.sh            # Test security compliance"
        
        if [ $warnings -gt 0 ]; then
            echo ""
            echo "⚠️ Note sui warning:"
            echo "- OWASP ZAP: Installazione manuale con 'docker pull zaproxy/zap-stable'"
            echo "- NPM tools: Riavvia terminale per aggiornare PATH"
            echo "- git-secrets: Opzionale per secret detection"
        fi
        
        return 0
    else
        log_error "❌ Tool essenziali mancanti - installazione fallita"
        echo ""
        echo "🔧 Risoluzione problemi:"
        echo "1. Controlla il log: $LOG_FILE"
        echo "2. Verifica connessione internet"
        echo "3. Riprova: ./prerequisites-security.sh"
        return 1
    fi
}

# Execute main function
main "$@"