#!/bin/bash

# Sync DevOps Configuration Script v4.0
# FASE 3: CI/CD Base con Jenkins

set -o pipefail

# Configurazioni
REPO_URL="https://github.com/mcatania72/CRM-System.git"
CRM_SYSTEM_DIR="$HOME/devops/CRM-System"
DEVOPS_DIR="$HOME/devops-pipeline-fase-3"
SYMLINK_DIR="$HOME/devops-scripts"
LOG_FILE="$HOME/sync-devops.log"
BACKUP_DIR="$HOME/devops-pipeline-fase-3_backup_$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# Funzione per verificare integrità dei file
verify_file_integrity() {
    local file_path="$1"
    local min_size="$2"
    local required_content="$3"
    
    if [ ! -f "$file_path" ]; then
        return 1
    fi
    
    local file_size=$(wc -c < "$file_path")
    if [ "$file_size" -lt "$min_size" ]; then
        return 1
    fi
    
    if [ -n "$required_content" ]; then
        if ! grep -q "$required_content" "$file_path"; then
            return 1
        fi
    fi
    
    return 0
}

# Funzione principale
main() {
    echo ""
    echo "======================================="
    echo "   CRM System - DevOps Sync Script v4.0"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    # Vai sempre nella home directory per evitare problemi di symlink
    cd "$HOME" || exit 1
    
    log_info "Inizializzazione sync DevOps config v4.0..."
    
    # Verifica e backup directory esistente
    if [ -d "$DEVOPS_DIR" ]; then
        log_warning "Directory devops-pipeline-fase-3 esistente. Creando backup..."
        if cp -r "$DEVOPS_DIR" "$BACKUP_DIR"; then
            log "Backup creato in: $BACKUP_DIR"
        else
            log_error "Impossibile creare backup"
            exit 1
        fi
    fi
    
    log_info "Rimozione directory progetto esistente..."
    rm -rf "$CRM_SYSTEM_DIR" 2>/dev/null || true
    
    log_info "Clone del repository CRM-System..."
    mkdir -p "$(dirname "$CRM_SYSTEM_DIR")"
    
    if git clone "$REPO_URL" "$CRM_SYSTEM_DIR"; then
        log_success "Repository clonato con successo"
    else
        log_error "Fallimento clone repository"
        # Ripristina backup se clone fallisce
        if [ -d "$BACKUP_DIR" ]; then
            log_info "Ripristino backup..."
            rm -rf "$DEVOPS_DIR"
            mv "$BACKUP_DIR" "$DEVOPS_DIR"
        fi
        exit 1
    fi
    
    log_info "Copia configurazione DevOps FASE 3..."
    rm -rf "$DEVOPS_DIR"
    
    if cp -r "$CRM_SYSTEM_DIR/devops-pipeline-fase-3" "$DEVOPS_DIR"; then
        log_success "Configurazione DevOps copiata"
    else
        log_error "Fallimento copia configurazione DevOps"
        exit 1
    fi
    
    # Verifica integrità files scaricati
    log_info "Verifica integrità files..."
    
    local files_ok=true
    
    # Verifica script principali
    if verify_file_integrity "$DEVOPS_DIR/prerequisites-jenkins.sh" 100 "FASE 3"; then
        local lines=$(wc -l < "$DEVOPS_DIR/prerequisites-jenkins.sh")
        log_success "✓ prerequisites-jenkins.sh verificato ($lines righe)"
    else
        log_error "✗ prerequisites-jenkins.sh fallito"
        files_ok=false
    fi
    
    if verify_file_integrity "$DEVOPS_DIR/deploy-jenkins.sh" 100 "FASE 3"; then
        local lines=$(wc -l < "$DEVOPS_DIR/deploy-jenkins.sh")
        log_success "✓ deploy-jenkins.sh verificato ($lines righe)"
    else
        log_error "✗ deploy-jenkins.sh fallito"
        files_ok=false
    fi
    
    if verify_file_integrity "$DEVOPS_DIR/test-jenkins.sh" 100 "FASE 3"; then
        local lines=$(wc -l < "$DEVOPS_DIR/test-jenkins.sh")
        log_success "✓ test-jenkins.sh verificato ($lines righe)"
    else
        log_error "✗ test-jenkins.sh fallito"
        files_ok=false
    fi
    
    if verify_file_integrity "$DEVOPS_DIR/sync-devops-config.sh" 100 "v4.0"; then
        local lines=$(wc -l < "$DEVOPS_DIR/sync-devops-config.sh")
        log_success "✓ sync-devops-config.sh verificato ($lines righe)"
    else
        log_error "✗ sync-devops-config.sh fallito"
        files_ok=false
    fi
    
    # Controlla che i file non abbiano contenuto problematico
    if ! grep -q "set -e" "$DEVOPS_DIR/test-jenkins.sh"; then
        log_success "✓ test-jenkins.sh verificato - nessun 'set -e' trovato"
    else
        log_warning "⚠ test-jenkins.sh contiene 'set -e' - possibili problemi"
    fi
    
    # Se la verifica fallisce, ripristina backup
    if [ "$files_ok" = false ]; then
        log_error "Verifica integrità fallita - ripristino backup"
        if [ -d "$BACKUP_DIR" ]; then
            rm -rf "$DEVOPS_DIR"
            mv "$BACKUP_DIR" "$DEVOPS_DIR"
            log_info "Backup ripristinato"
        fi
        exit 1
    fi
    
    # Rendi eseguibili tutti gli script
    chmod +x "$DEVOPS_DIR"/*.sh 2>/dev/null || true
    
    # Crea/aggiorna symlink per facilità accesso
    if [ -L "$SYMLINK_DIR" ]; then
        rm "$SYMLINK_DIR"
    fi
    ln -sf "$DEVOPS_DIR" "$SYMLINK_DIR"
    
    # Rimuovi backup se tutto è andato bene
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR"
        log_success "Backup rimosso - sync completato con successo"
    fi
    
    echo ""
    echo "======================================="
    echo "   SINCRONIZZAZIONE COMPLETATA v4.0"
    echo "======================================="
    echo "Directory progetto: $CRM_SYSTEM_DIR"
    echo "Directory DevOps FASE 3: $DEVOPS_DIR"
    echo "Directory corrente: $(pwd)"
    echo "Symlink: $SYMLINK_DIR"
    echo "Log file: $LOG_FILE"
    
    echo ""
    echo "File sincronizzati (directory corrente):"
    
    # Lista file con dimensioni dalla directory corrente
    if [ -d "$DEVOPS_DIR" ]; then
        cd "$DEVOPS_DIR" || exit 1
        for file in *.sh README.md; do
            if [ -f "$file" ]; then
                local size=$(wc -c < "$file" 2>/dev/null || echo 0)
                local lines=$(wc -l < "$file" 2>/dev/null || echo 0)
                echo "  ✓ $file ($lines righe, $size bytes)"
            fi
        done
    fi
    
    echo ""
    echo "Prossimi passi (sei già nella directory corretta):"
    echo "1. ./prerequisites-jenkins.sh    # Verifica/installa Jenkins"
    echo "2. ./deploy-jenkins.sh           # Configura CI/CD pipeline"
    echo "3. ./test-jenkins.sh             # Test completi pipeline"
    
    log_success "Sei ora posizionato nella directory DevOps FASE 3 sincronizzata"
    
    # Posizionati nella directory corretta alla fine
    cd "$DEVOPS_DIR" || exit 1
    log "Sync completed successfully - positioned in $DEVOPS_DIR"
}

# Esecuzione script
main "$@"