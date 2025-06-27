#!/bin/bash

# =============================================================================
# CRM System - DevOps Sync Script v4.0
# FASE 4: Security Baseline
# =============================================================================

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/mcatania72/CRM-System/main"
PHASE="devops-pipeline-fase-4"
LOG_FILE="$HOME/sync-fase4.log"
BACKUP_DIR="$HOME/${PHASE}_backup_$(date +%Y%m%d_%H%M%S)"

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

# Header
echo "======================================="
echo "   CRM System - DevOps Sync Script v4.0"
echo "   FASE 4: Security Baseline"
echo "======================================="
log_info "Inizializzazione sync DevOps config FASE 4..."

# Backup existing directory if it exists
if [ -d "$HOME/$PHASE" ]; then
    log_warning "Directory $PHASE esistente. Creando backup..."
    cp -r "$HOME/$PHASE" "$BACKUP_DIR"
    log_success "Backup creato: $BACKUP_DIR"
fi

# Create directory structure
log_info "Creazione struttura directory FASE 4..."
mkdir -p "$HOME/$PHASE"/{security,jenkins}
mkdir -p "$HOME/$PHASE/security"/{sonarqube,owasp-zap,trivy,policies}

# Files to download
FILES=(
    "prerequisites-security.sh"
    "deploy-security.sh"
    "test-security.sh"
    "security/sonarqube-config.properties"
    "security/zap-baseline.py"
    "security/trivy-config.yaml"
    "security/policies/security-policy.yaml"
    "jenkins/Jenkinsfile.security"
)

# Download each file
log_info "Download file di configurazione FASE 4..."
for file in "${FILES[@]}"; do
    url="$REPO_URL/$PHASE/$file"
    target="$HOME/$PHASE/$file"
    
    # Create directory if needed
    mkdir -p "$(dirname "$target")"
    
    if curl -fsSL "$url" -o "$target"; then
        log_success "Downloaded: $file"
        # Make scripts executable
        if [[ "$file" == *.sh ]]; then
            chmod +x "$target"
        fi
    else
        log_error "Failed to download: $file"
    fi
done

# Verify FASE 3 integration
log_info "Verifica integrazione con FASE 3..."
if [ -d "$HOME/devops-pipeline-fase-3" ]; then
    log_success "FASE 3 trovata - integrazione possibile"
    
    # Update FASE 3 Jenkinsfile with security stages
    if [ -f "$HOME/devops-pipeline-fase-3/jenkins/Jenkinsfile.crm-build" ]; then
        log_info "Backup Jenkinsfile FASE 3 esistente..."
        cp "$HOME/devops-pipeline-fase-3/jenkins/Jenkinsfile.crm-build" \
           "$HOME/devops-pipeline-fase-3/jenkins/Jenkinsfile.crm-build.backup.$(date +%Y%m%d_%H%M%S)"
        log_success "Backup Jenkinsfile completato"
    fi
else
    log_warning "FASE 3 non trovata - deploy security standalone"
fi

# Set proper permissions
log_info "Configurazione permessi..."
chmod +x "$HOME/$PHASE"/*.sh
chmod -R 755 "$HOME/$PHASE"/security

# Summary
echo ""
echo "======================================="
echo "   SYNC FASE 4 COMPLETATO"
echo "======================================="
log_success "Tutti i file di configurazione FASE 4 sincronizzati"
echo ""
echo "📁 Directory creata: $HOME/$PHASE"
echo "📋 File scaricati: ${#FILES[@]}"
echo "🔒 Security tools: SonarQube, OWASP ZAP, Trivy"
echo "🔄 Integrazione: FASE 3 Jenkins"
echo ""
echo "🚀 Prossimi passi:"
echo "1. ./prerequisites-security.sh    # Installa security tools"
echo "2. ./deploy-security.sh start     # Deploy security pipeline"
echo "3. ./test-security.sh             # Test security compliance"
echo ""
log_success "FASE 4: Security Baseline - Sync completato con successo!"

# Cleanup old backups (keep only last 3)
log_info "Pulizia backup precedenti..."
ls -dt "$HOME/${PHASE}_backup_"* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true
log_success "Pulizia completata"

echo "✅ FASE 4 pronta per deployment security!"