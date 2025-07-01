#!/bin/bash

# =============================================================================
# SYNC DEVOPS CONFIG - FASE 7
# =============================================================================
# Cancella contenuto devops-pipeline-fase-7 su DEV_VM e scarica ultima versione
# =============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
REPO_URL="https://github.com/mcatania72/CRM-System_NEW.git"
LOCAL_REPO_DIR="$HOME/CRM-System_NEW"
FASE7_DIR="$LOCAL_REPO_DIR/devops-pipeline-fase-7"

# Funzioni di utility
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=============================================="
    echo "  SYNC DEVOPS CONFIG - FASE 7"
    echo "  Infrastructure as Code Sync"
    echo "=============================================="
    echo ""
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

backup_existing_work() {
    if [ -d "$FASE7_DIR" ]; then
        log_warning "Fase 7 directory esistente trovata"
        
        # Crea backup se ci sono modifiche locali
        BACKUP_DIR="$HOME/fase7_backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$FASE7_DIR" "$BACKUP_DIR" 2>/dev/null || true
        log_info "Backup creato: $BACKUP_DIR"
        
        # Rimuovi directory esistente
        rm -rf "$FASE7_DIR"
        log_info "Directory Fase 7 esistente rimossa"
    fi
}

sync_repository() {
    log_info "Sincronizzazione repository..."
    
    if [ -d "$LOCAL_REPO_DIR" ]; then
        cd "$LOCAL_REPO_DIR"
        
        # Reset hard per evitare conflitti
        git reset --hard HEAD 2>/dev/null || true
        
        # Pull latest changes
        git pull origin main
        log_success "Repository aggiornato"
    else
        # Clone repository se non esiste
        log_info "Cloning repository..."
        cd "$HOME"
        git clone "$REPO_URL"
        log_success "Repository clonato"
    fi
}

verify_fase7_content() {
    log_info "Verifica contenuti Fase 7..."
    
    if [ ! -d "$FASE7_DIR" ]; then
        log_error "Directory devops-pipeline-fase-7 non trovata!"
        exit 1
    fi
    
    # Verifica script principali
    REQUIRED_SCRIPTS=(
        "sync-devops-config.sh"
        "prerequisites.sh"
        "deploy_infrastructure.sh"
        "test_infrastructure.sh"
    )
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [ -f "$FASE7_DIR/$script" ]; then
            log_success "✅ $script presente"
            chmod +x "$FASE7_DIR/$script"
        else
            log_warning "⚠️  $script mancante"
        fi
    done
    
    # Verifica directory terraform
    if [ -d "$FASE7_DIR/terraform" ]; then
        log_success "✅ Directory terraform presente"
    else
        log_warning "⚠️  Directory terraform mancante"
    fi
}

setup_working_directory() {
    log_info "Setup working directory..."
    
    cd "$FASE7_DIR"
    
    # Crea link simbolico per facilità
    if [ ! -L "$HOME/fase7" ]; then
        ln -sf "$FASE7_DIR" "$HOME/fase7"
        log_success "Link simbolico creato: ~/fase7"
    fi
    
    # Setup permessi
    find . -name "*.sh" -exec chmod +x {} \;
    log_success "Permessi script configurati"
}

show_next_steps() {
    echo ""
    log_success "🎉 SYNC COMPLETATO!"
    echo ""
    echo -e "${BLUE}📁 Working Directory:${NC} $FASE7_DIR"
    echo -e "${BLUE}🔗 Quick Access:${NC} ~/fase7"
    echo ""
    echo -e "${GREEN}🚀 NEXT STEPS:${NC}"
    echo ""
    echo "1. Verifica prerequisites:"
    echo "   cd ~/fase7 && ./prerequisites.sh"
    echo ""
    echo "2. Deploy infrastructure:"
    echo "   ./deploy_infrastructure.sh"
    echo ""
    echo "3. Test infrastructure:"
    echo "   ./test_infrastructure.sh"
    echo ""
    echo "4. Deploy application (dopo infrastructure):"
    echo "   ./deploy_application.sh"
    echo ""
    echo -e "${YELLOW}💡 TIP:${NC} Usa 'cd ~/fase7' per accesso rapido"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    print_header
    
    log_info "Avvio sincronizzazione devops-pipeline-fase-7..."
    
    # Step 1: Backup esistente se presente
    backup_existing_work
    
    # Step 2: Sync repository
    sync_repository
    
    # Step 3: Verifica contenuti
    verify_fase7_content
    
    # Step 4: Setup working directory
    setup_working_directory
    
    # Step 5: Show next steps
    show_next_steps
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
