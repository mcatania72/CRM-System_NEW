#!/bin/bash

# ============================================
# CRM System - Testing Prerequisites v5.0
# FASE 5: Testing Avanzato Prerequisites
# ============================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $1" >> ~/prerequisites-testing.log
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> ~/prerequisites-testing.log
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> ~/prerequisites-testing.log
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> ~/prerequisites-testing.log
}

# Script start
echo "======================================="
echo "   CRM System - Testing Prerequisites"
echo "   FASE 5: Testing Avanzato"
echo "======================================="

log_info "Avvio installazione testing prerequisites..."

# Check mode
CHECK_MODE=false
if [[ "$1" == "--check" ]]; then
    CHECK_MODE=true
    log_info "Modalità verifica attivata"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install npm package globally if not exists
install_npm_global() {
    local package="$1"
    local command="$2"
    
    if command_exists "$command"; then
        log_success "✅ $package già installato"
        return 0
    fi
    
    if [[ "$CHECK_MODE" == "true" ]]; then
        log_warning "⚠️ $package non trovato"
        return 1
    fi
    
    log_info "Installazione $package..."
    if npm install -g "$package"; then
        log_success "✅ $package installato con successo"
        return 0
    else
        log_error "❌ Errore installazione $package"
        return 1
    fi
}

# Function to install system package if not exists
install_system_package() {
    local package="$1"
    local check_command="$2"
    
    if command_exists "$check_command"; then
        log_success "✅ $package già installato"
        return 0
    fi
    
    if [[ "$CHECK_MODE" == "true" ]]; then
        log_warning "⚠️ $package non trovato"
        return 1
    fi
    
    log_info "Installazione $package..."
    if sudo apt-get update && sudo apt-get install -y "$package"; then
        log_success "✅ $package installato con successo"
        return 0
    else
        log_error "❌ Errore installazione $package"
        return 1
    fi
}

# Check basic prerequisites
log_info "=== Verifica Prerequisiti Base ==="

# Node.js and npm
if command_exists node && command_exists npm; then
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "✅ Node.js $NODE_VERSION"
    log_success "✅ npm $NPM_VERSION"
    
    # Check Node.js version (minimum 16)
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'.' -f1 | tr -d 'v')
    if [[ "$NODE_MAJOR" -ge 16 ]]; then
        log_success "✅ Node.js versione compatibile"
    else
        log_warning "⚠️ Node.js versione $NODE_VERSION potrebbe essere troppo vecchia (raccomandato ≥16)"
    fi
else
    log_error "❌ Node.js e npm sono prerequisiti obbligatori"
    exit 1
fi

# Docker (for integration testing)
if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    log_success "✅ Docker disponibile: $DOCKER_VERSION"
else
    log_warning "⚠️ Docker non trovato - integration testing limitato"
fi

# Git
if command_exists git; then
    GIT_VERSION=$(git --version)
    log_success "✅ Git disponibile: $GIT_VERSION"
else
    log_warning "⚠️ Git non trovato"
fi

# Install Testing Tools
log_info "=== Installazione Testing Tools ==="

# Jest (Backend Unit Testing)
if [[ "$CHECK_MODE" == "true" ]]; then
    if npm list -g jest >/dev/null 2>&1; then
        log_success "✅ Jest installato globalmente"
    else
        log_warning "⚠️ Jest non trovato"
    fi
else
    log_info "Installazione Jest..."
    npm install -g jest @types/jest ts-jest supertest @types/supertest 2>/dev/null || log_warning "⚠️ Errore installazione Jest globale"
fi

# Playwright (E2E Testing)
install_npm_global "@playwright/test" "playwright"

if command_exists playwright && [[ "$CHECK_MODE" == "false" ]]; then
    log_info "Installazione browser Playwright..."
    npx playwright install chromium firefox webkit 2>/dev/null || log_warning "⚠️ Errore installazione browser Playwright"
fi

# Artillery (Performance Testing)
install_npm_global "artillery" "artillery"

# Lighthouse CI (Performance Testing)
install_npm_global "@lhci/cli" "lhci"

# Additional testing utilities
install_npm_global "newman" "newman"  # Postman collection runner
install_npm_global "@pact-foundation/pact" "pact"  # Contract testing (optional)

# System dependencies for browser testing
log_info "=== Verifica Dipendenze Sistema per Browser Testing ==="

# Dependencies for Playwright browsers
SYSTEM_DEPS=("libnss3" "libatk-bridge2.0-0" "libxss1" "libasound2")
for dep in "${SYSTEM_DEPS[@]}"; do
    if dpkg -l | grep -q "$dep"; then
        log_success "✅ $dep presente"
    else
        if [[ "$CHECK_MODE" == "false" ]]; then
            log_info "Installazione $dep..."
            sudo apt-get install -y "$dep" >/dev/null 2>&1 || log_warning "⚠️ Errore installazione $dep"
        else
            log_warning "⚠️ $dep non trovato"
        fi
    fi
done

# Install additional testing utilities if not in check mode
if [[ "$CHECK_MODE" == "false" ]]; then
    log_info "=== Configurazione Testing Environment ==="
    
    # Create test directories if they don't exist
    mkdir -p ~/testing-workspace/{reports,coverage,screenshots,videos}
    log_success "✅ Directory testing workspace create"
    
    # Install additional npm packages locally in workspace
    cd ~/testing-workspace
    
    if [[ ! -f "package.json" ]]; then
        log_info "Inizializzazione package.json per testing workspace..."
        npm init -y >/dev/null 2>&1
        
        # Install common testing dependencies
        log_info "Installazione dipendenze testing workspace..."
        npm install --save-dev \
            jest \
            @types/jest \
            ts-jest \
            supertest \
            @types/supertest \
            vitest \
            @testing-library/react \
            @testing-library/jest-dom \
            @testing-library/user-event \
            playwright \
            @playwright/test >/dev/null 2>&1 || log_warning "⚠️ Alcuni pacchetti potrebbero non essere installati"
    fi
    
    cd - >/dev/null
fi

# Check integration with previous phases
log_info "=== Verifica Integrazione Fasi Precedenti ==="

PHASES=("devops-pipeline-fase-1" "devops-pipeline-fase-2" "devops-pipeline-fase-3" "devops-pipeline-fase-4")
INTEGRATION_SCORE=0

for phase in "${PHASES[@]}"; do
    if [[ -d "../$phase" ]]; then
        log_success "✅ $phase disponibile"
        ((INTEGRATION_SCORE++))
        
        # Check specific integration points
        case "$phase" in
            "devops-pipeline-fase-1")
                if [[ -f "../$phase/deploy.sh" ]]; then
                    log_success "✅ FASE 1 deploy script disponibile per testing"
                fi
                ;;
            "devops-pipeline-fase-2")
                if [[ -f "../$phase/deploy-containers.sh" ]]; then
                    log_success "✅ FASE 2 container deployment disponibile per integration testing"
                fi
                ;;
            "devops-pipeline-fase-3")
                if [[ -f "../$phase/deploy-jenkins.sh" ]]; then
                    log_success "✅ FASE 3 Jenkins disponibile per CI/CD testing"
                fi
                ;;
            "devops-pipeline-fase-4")
                if [[ -f "../$phase/deploy-security.sh" ]]; then
                    log_success "✅ FASE 4 Security tools disponibili per security testing"
                fi
                ;;
        esac
    else
        log_warning "⚠️ $phase non trovata"
    fi
done

log_info "Integrazione fasi: $INTEGRATION_SCORE/4 disponibili"

# Performance and resource checks
log_info "=== Verifica Risorse Sistema ==="

# Memory check
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
if [[ "$MEMORY_GB" -ge 4 ]]; then
    log_success "✅ Memoria sistema: ${MEMORY_GB}GB (sufficiente)"
else
    log_warning "⚠️ Memoria sistema: ${MEMORY_GB}GB (raccomandato ≥4GB per E2E testing)"
fi

# Disk space check
DISK_AVAILABLE=$(df -h . | awk 'NR==2{print $4}' | sed 's/G//')
if [[ "${DISK_AVAILABLE%%.*}" -ge 5 ]]; then
    log_success "✅ Spazio disco: ${DISK_AVAILABLE} disponibile"
else
    log_warning "⚠️ Spazio disco: ${DISK_AVAILABLE} (raccomandato ≥5GB)"
fi

# Summary
echo ""
echo "======================================="
echo "   RISULTATI PREREQUISITES"
echo "======================================="

# Count successful installations
SUCCESS_COUNT=0
TOTAL_COUNT=8

# Check final status of key tools
TOOLS_STATUS=(
    "node:Node.js"
    "npm:NPM"
    "playwright:Playwright"
    "artillery:Artillery"
    "lhci:Lighthouse CI"
    "newman:Newman"
    "jest:Jest"
    "docker:Docker"
)

for tool_info in "${TOOLS_STATUS[@]}"; do
    IFS=':' read -r cmd name <<< "$tool_info"
    if command_exists "$cmd" || npm list -g "$cmd" >/dev/null 2>&1; then
        log_success "✅ $name disponibile"
        ((SUCCESS_COUNT++))
    else
        log_warning "⚠️ $name non disponibile"
    fi
done

SUCCESS_PERCENTAGE=$((SUCCESS_COUNT * 100 / TOTAL_COUNT))

echo ""
echo "Testing Tools: $SUCCESS_COUNT/$TOTAL_COUNT installati"
echo "Percentuale Successo: $SUCCESS_PERCENTAGE%"
echo "Integrazione Fasi: $INTEGRATION_SCORE/4 disponibili"

if [[ "$SUCCESS_PERCENTAGE" -ge 80 ]]; then
    log_success "🎉 Prerequisites testing completati con successo!"
    echo ""
    echo "Prossimi passi:"
    echo "1. ./deploy-testing.sh start    # Avvia testing pipeline"
    echo "2. ./test-advanced.sh          # Esegui test suite completa"
    echo ""
    echo "Testing avanzato pronto! 🧪"
    exit 0
else
    log_error "❌ Prerequisites insufficienti ($SUCCESS_PERCENTAGE%). Richiesto ≥80%"
    echo ""
    echo "Soluzioni:"
    echo "• Installare Node.js ≥16: https://nodejs.org/"
    echo "• Installare Docker: https://docs.docker.com/install/"
    echo "• Eseguire: npm install -g playwright artillery @lhci/cli"
    echo "• Riprovare: ./prerequisites-testing.sh"
    exit 1
fi

log_info "Prerequisites script completato. Log salvato in ~/prerequisites-testing.log"