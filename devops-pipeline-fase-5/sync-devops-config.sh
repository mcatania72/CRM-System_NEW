#!/bin/bash

# ============================================
# CRM System - DevOps Sync Script v5.0
# FASE 5: Testing Avanzato (FIXED)
# ============================================

# NO set -e per gestire meglio gli errori

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $1" >> ~/sync-testing.log
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> ~/sync-testing.log
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> ~/sync-testing.log
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> ~/sync-testing.log
}

# Script start
echo "======================================="
echo "   CRM System - DevOps Sync Script v5.0"
echo "   FASE 5: Testing Avanzato"
echo "======================================="

log_info "Inizializzazione sync DevOps config FASE 5..."

# Check if we're in the right directory
if [[ ! "$(basename "$(pwd)")" == "devops-pipeline-fase-5" ]]; then
    log_warning "Non sei nella directory devops-pipeline-fase-5. Creando e spostandosi..."
    mkdir -p ~/devops-pipeline-fase-5
    cd ~/devops-pipeline-fase-5
fi

# Backup existing config if present
if [[ -d "./testing" ]]; then
    log_warning "⚠️ Directory testing esistente."
    BACKUP_DIR="testing-backup-$(date +%Y%m%d_%H%M%S)"
    log_info "Creando backup in $BACKUP_DIR"
    mv testing "$BACKUP_DIR"
fi

# Create necessary directories - FIXED VERSION
log_info "Creazione struttura directory FASE 5..."

# Create base directories first
mkdir -p testing config jenkins reports scripts
mkdir -p deploy-testing test-advanced

# Create testing subdirectories
mkdir -p testing/unit testing/integration testing/e2e testing/performance testing/contracts testing/config
mkdir -p testing/unit/backend-tests testing/unit/frontend-tests
mkdir -p testing/integration/api-tests testing/integration/database-tests
mkdir -p testing/e2e/tests testing/e2e/fixtures testing/e2e/screenshots
mkdir -p testing/performance/scripts testing/performance/reports
mkdir -p testing/contracts/pact testing/contracts/schemas

# Create reports subdirectories
mkdir -p reports/coverage reports/test-results reports/performance

log_success "✅ Struttura directory creata"

# Repository and branch info
REPO_URL="https://raw.githubusercontent.com/mcatania72/CRM-System/main"
BRANCH="main"
FASE_DIR="devops-pipeline-fase-5"

log_info "Sincronizzazione con repository GitHub..."
log_info "Repository: mcatania72/CRM-System"
log_info "Branch: $BRANCH"
log_info "Directory: $FASE_DIR"

# Function to download file with error handling
download_file() {
    local url="$1"
    local dest="$2"
    local optional="$3"
    
    log_info "Scaricando: $(basename "$dest")"
    
    if curl -s -f "$url" -o "$dest"; then
        chmod +x "$dest" 2>/dev/null || true
        log_success "✅ $(basename "$dest") scaricato"
        return 0
    else
        if [[ "$optional" == "optional" ]]; then
            log_warning "⚠️ File opzionale non trovato: $(basename "$dest")"
            return 0
        else
            log_error "❌ Errore scaricamento: $(basename "$dest")"
            return 1
        fi
    fi
}

# Download main scripts
log_info "=== Scaricamento Script Principali ==="
download_file "$REPO_URL/$FASE_DIR/prerequisites-testing.sh" "./prerequisites-testing.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing.sh" "./deploy-testing.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced.sh" "./test-advanced.sh"

# Download deploy-testing modules
log_info "=== Scaricamento Deploy-Testing Modules ==="
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-prerequisites.sh" "./deploy-testing/deploy-testing-prerequisites.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-environment.sh" "./deploy-testing/deploy-testing-environment.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-services.sh" "./deploy-testing/deploy-testing-services.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-stop-services.sh" "./deploy-testing/deploy-testing-stop-services.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-status.sh" "./deploy-testing/deploy-testing-status.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-smoke-tests.sh" "./deploy-testing/deploy-testing-smoke-tests.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-cleanup.sh" "./deploy-testing/deploy-testing-cleanup.sh"

# Download test-advanced modules
log_info "=== Scaricamento Test-Advanced Modules ==="
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-unit.sh" "./test-advanced/test-unit.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-integration.sh" "./test-advanced/test-integration.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-e2e.sh" "./test-advanced/test-e2e.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-performance.sh" "./test-advanced/test-performance.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-security.sh" "./test-advanced/test-security.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/generate-report.sh" "./test-advanced/generate-report.sh"

# Download configuration files
log_info "=== Scaricamento Configurazioni ==="
download_file "$REPO_URL/$FASE_DIR/config/jest.config.js" "./config/jest.config.js"
download_file "$REPO_URL/$FASE_DIR/config/playwright.config.js" "./config/playwright.config.js"
download_file "$REPO_URL/$FASE_DIR/config/artillery.config.yml" "./config/artillery.config.yml"

# Download testing structure
log_info "=== Scaricamento Testing Structure ==="
download_file "$REPO_URL/$FASE_DIR/testing/config/jest.setup.js" "./testing/config/jest.setup.js"
download_file "$REPO_URL/$FASE_DIR/testing/unit/sample.test.js" "./testing/unit/sample.test.js"
download_file "$REPO_URL/$FASE_DIR/testing/e2e/sample.spec.js" "./testing/e2e/sample.spec.js"

# Download utility scripts
log_info "=== Scaricamento Script di Utilità ==="
download_file "$REPO_URL/$FASE_DIR/scripts/setup-test-data.sh" "./scripts/setup-test-data.sh"
download_file "$REPO_URL/$FASE_DIR/scripts/generate-reports.sh" "./scripts/generate-reports.sh" optional
download_file "$REPO_URL/$FASE_DIR/scripts/cleanup-tests.sh" "./scripts/cleanup-tests.sh" optional

# Set executable permissions
log_info "Impostazione permessi eseguibili..."
chmod +x *.sh 2>/dev/null || true
chmod +x deploy-testing/*.sh 2>/dev/null || true
chmod +x test-advanced/*.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

# Create .gitignore for testing
log_info "Creazione .gitignore per testing..."
cat > .gitignore << 'EOF'
# Testing artifacts
node_modules/
coverage/
reports/
test-results/
playwright-report/
test-results.xml
*.log

# Performance testing
artillery-output/
lighthouse-reports/

# E2E testing
screenshots/
videos/

# Contract testing
pact/logs/
pact/pacts/

# Temporary files
*.tmp
*.temp
.DS_Store
Thumbs.db
EOF

# Verify critical files
log_info "=== Verifica File Critici ==="
CRITICAL_FILES=(
    "prerequisites-testing.sh"
    "deploy-testing.sh"
    "test-advanced.sh"
    "config/jest.config.js"
    "config/playwright.config.js"
    "deploy-testing/deploy-testing-prerequisites.sh"
    "test-advanced/test-unit.sh"
)

MISSING_FILES=0
for file in "${CRITICAL_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "✅ $file presente"
    else
        log_error "❌ $file mancante"
        ((MISSING_FILES++))
    fi
done

# Integration check with previous phases
log_info "=== Verifica Integrazione Fasi Precedenti ==="
PHASES=("devops-pipeline-fase-1" "devops-pipeline-fase-2" "devops-pipeline-fase-3" "devops-pipeline-fase-4")
for phase in "${PHASES[@]}"; do
    if [[ -d "../$phase" ]]; then
        log_success "✅ $phase disponibile per integrazione"
    else
        log_warning "⚠️ $phase non trovata - alcune funzionalità potrebbero essere limitate"
    fi
done

# Check if CRM System repository is available
if [[ -d "../CRM-System" ]]; then
    log_success "✅ Repository CRM-System trovato"
    
    # Check if we can access backend and frontend
    if [[ -d "../CRM-System/backend" && -d "../CRM-System/frontend" ]]; then
        log_success "✅ Backend e Frontend accessibili per testing"
    else
        log_warning "⚠️ Backend/Frontend non accessibili - clonare repository CRM-System"
    fi
else
    log_warning "⚠️ Repository CRM-System non trovato nella directory parent"
    log_info "Per testing completo, clonare: git clone https://github.com/mcatania72/CRM-System.git"
fi

# Summary
echo ""
echo "======================================="
echo "   SINCRONIZZAZIONE COMPLETATA"
echo "======================================="

if [[ $MISSING_FILES -eq 0 ]]; then
    log_success "🎉 Tutti i file critici sincronizzati con successo!"
    echo ""
    echo "Prossimi passi:"
    echo "1. ./prerequisites-testing.sh    # Installa testing tools"
    echo "2. ./deploy-testing.sh start     # Avvia testing pipeline"
    echo "3. ./test-advanced.sh all        # Esegui test suite completa"
    echo ""
    echo "Per test specifici:"
    echo "• ./test-advanced.sh unit        # Unit tests"
    echo "• ./test-advanced.sh integration # Integration tests"
    echo "• ./test-advanced.sh e2e         # E2E tests"
    echo "• ./test-advanced.sh performance # Performance tests"
    echo "• ./test-advanced.sh security    # Security tests"
else
    log_error "❌ $MISSING_FILES file critici mancanti. Riprovare la sincronizzazione."
    exit 1
fi

log_info "Sync script completato. Log salvato in ~/sync-testing.log"
echo "📊 Logs: tail -f ~/sync-testing.log"
echo "📁 Directory: $(pwd)"
echo "🚀 FASE 5: Testing Avanzato pronta!"