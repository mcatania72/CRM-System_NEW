#!/bin/bash

# ============================================
# CRM System - DevOps Sync Script v5.1
# FASE 5: Testing Avanzato (FIXED - FORCE UPDATE)
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
echo "   CRM System - DevOps Sync Script v5.1"
echo "   FASE 5: Testing Avanzato (FORCE UPDATE)"
echo "======================================="

log_info "Inizializzazione sync DevOps config FASE 5..."

# Check if we're in the right directory
if [[ ! "$(basename "$(pwd)")" == "devops-pipeline-fase-5" ]]; then
    log_warning "Non sei nella directory devops-pipeline-fase-5. Creando e spostandosi..."
    mkdir -p ~/devops-pipeline-fase-5
    cd ~/devops-pipeline-fase-5
fi

# Backup existing config if present (only testing directory)
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

# ENHANCED Function to download file with FORCE UPDATE
download_file() {
    local url="$1"
    local dest="$2"
    local optional="$3"
    
    local filename=$(basename "$dest")
    log_info "Scaricando (FORCE): $filename"
    
    # Create directory if it doesn't exist
    local destdir=$(dirname "$dest")
    mkdir -p "$destdir"
    
    # FORCE REMOVE existing file to ensure fresh download
    if [[ -f "$dest" ]]; then
        rm -f "$dest"
        log_info "  → File esistente rimosso: $filename"
    fi
    
    # Download with verbose error reporting
    if curl -f -L --max-time 30 --retry 3 "$url" -o "$dest" 2>/tmp/curl_error.log; then
        # Set executable permissions for .sh files
        if [[ "$dest" == *.sh ]]; then
            chmod +x "$dest"
        fi
        
        # Verify file was actually downloaded and has content
        if [[ -f "$dest" && -s "$dest" ]]; then
            local size=$(stat -c%s "$dest" 2>/dev/null || echo "0")
            log_success "✅ $filename scaricato (${size} bytes)"
            return 0
        else
            log_error "❌ File scaricato ma vuoto: $filename"
            return 1
        fi
    else
        if [[ "$optional" == "optional" ]]; then
            log_warning "⚠️ File opzionale non trovato: $filename"
            return 0
        else
            log_error "❌ Errore scaricamento: $filename"
            log_error "   URL: $url"
            if [[ -f /tmp/curl_error.log ]]; then
                log_error "   Error: $(cat /tmp/curl_error.log)"
            fi
            return 1
        fi
    fi
}

# Download main scripts with FORCE UPDATE
log_info "=== Scaricamento Script Principali (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/prerequisites-testing.sh" "./prerequisites-testing.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing.sh" "./deploy-testing.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced.sh" "./test-advanced.sh"

# Download deploy-testing modules
log_info "=== Scaricamento Deploy-Testing Modules (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-prerequisites.sh" "./deploy-testing/deploy-testing-prerequisites.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-environment.sh" "./deploy-testing/deploy-testing-environment.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-services.sh" "./deploy-testing/deploy-testing-services.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-stop-services.sh" "./deploy-testing/deploy-testing-stop-services.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-status.sh" "./deploy-testing/deploy-testing-status.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-smoke-tests.sh" "./deploy-testing/deploy-testing-smoke-tests.sh"
download_file "$REPO_URL/$FASE_DIR/deploy-testing/deploy-testing-cleanup.sh" "./deploy-testing/deploy-testing-cleanup.sh"

# Download test-advanced modules with FORCE UPDATE
log_info "=== Scaricamento Test-Advanced Modules (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-unit.sh" "./test-advanced/test-unit.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-integration.sh" "./test-advanced/test-integration.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-e2e.sh" "./test-advanced/test-e2e.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-e2e-simple.sh" "./test-advanced/test-e2e-simple.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-performance.sh" "./test-advanced/test-performance.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/test-security.sh" "./test-advanced/test-security.sh"
download_file "$REPO_URL/$FASE_DIR/test-advanced/generate-report.sh" "./test-advanced/generate-report.sh"

# Download configuration files
log_info "=== Scaricamento Configurazioni (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/config/jest.config.js" "./config/jest.config.js"
download_file "$REPO_URL/$FASE_DIR/config/playwright.config.js" "./config/playwright.config.js"
download_file "$REPO_URL/$FASE_DIR/config/artillery.config.yml" "./config/artillery.config.yml"

# Download testing structure
log_info "=== Scaricamento Testing Structure (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/testing/config/jest.setup.js" "./testing/config/jest.setup.js"
download_file "$REPO_URL/$FASE_DIR/testing/unit/sample.test.js" "./testing/unit/sample.test.js"
download_file "$REPO_URL/$FASE_DIR/testing/e2e/sample.spec.js" "./testing/e2e/sample.spec.js"

# Download utility scripts
log_info "=== Scaricamento Script di Utilità (FORCE) ==="
download_file "$REPO_URL/$FASE_DIR/scripts/setup-test-data.sh" "./scripts/setup-test-data.sh"
download_file "$REPO_URL/$FASE_DIR/scripts/generate-reports.sh" "./scripts/generate-reports.sh" optional
download_file "$REPO_URL/$FASE_DIR/scripts/cleanup-tests.sh" "./scripts/cleanup-tests.sh" optional

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

# Verify critical files with size check
log_info "=== Verifica File Critici ==="
CRITICAL_FILES=(
    "prerequisites-testing.sh"
    "deploy-testing.sh"
    "test-advanced.sh"
    "config/jest.config.js"
    "config/playwright.config.js"
    "deploy-testing/deploy-testing-prerequisites.sh"
    "test-advanced/test-unit.sh"
    "test-advanced/test-e2e-simple.sh"
    "test-advanced/test-security.sh"
)

MISSING_FILES=0
for file in "${CRITICAL_FILES[@]}"; do
    if [[ -f "$file" && -s "$file" ]]; then
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        log_success "✅ $file presente (${size} bytes)"
    else
        log_error "❌ $file mancante o vuoto"
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
if [[ -d "$HOME/devops/CRM-System" ]]; then
    log_success "✅ Repository CRM-System trovato in ~/devops/"
elif [[ -d "../CRM-System" ]]; then
    log_success "✅ Repository CRM-System trovato (parent directory)"
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
    log_success "🎉 Tutti i file critici sincronizzati con successo! (FORCE UPDATE)"
    echo ""
    echo "Prossimi passi:"
    echo "1. ./prerequisites-testing.sh    # Installa testing tools"
    echo "2. ./deploy-testing.sh start     # Avvia testing pipeline"
    echo "3. ./test-advanced.sh e2e-fast   # Test veloci"
    echo "4. ./test-advanced.sh all        # Test suite completa"
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