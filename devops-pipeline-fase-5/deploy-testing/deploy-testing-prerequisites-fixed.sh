#!/bin/bash

# =======================================
#   Deploy Testing - Prerequisites Check
#   FASE 5: Step 1 (FIXED - No set -e)
# =======================================

# NO set -e per gestire meglio gli errori

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[PREREQUISITES]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PREREQUISITES]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[PREREQUISITES]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[PREREQUISITES]${NC} ⚠️ $1"
}

log_info "Verifica prerequisiti testing environment..."

# Check if FASE 1-4 are available
if [ ! -d "$HOME/devops-pipeline-fase-1" ]; then
    log_error "FASE 1 non trovata. Esegui prima le fasi precedenti."
    exit 1
fi

log_success "FASE 1 trovata"

if [ ! -d "$HOME/devops-pipeline-fase-2" ]; then
    log_warning "FASE 2 non trovata - testing solo in modalità native."
else
    log_success "FASE 2 trovata"
fi

if [ ! -d "$HOME/devops-pipeline-fase-3" ]; then
    log_warning "FASE 3 non trovata - testing senza Jenkins integration."
else
    log_success "FASE 3 trovata"
fi

# Check testing tools
missing_tools=()

if ! command -v jest >/dev/null 2>&1; then
    missing_tools+=("jest")
fi

if ! command -v playwright >/dev/null 2>&1; then
    missing_tools+=("playwright")
fi

if ! command -v artillery >/dev/null 2>&1; then
    missing_tools+=("artillery")
fi

if [ ${#missing_tools[@]} -gt 0 ]; then
    log_error "Testing tools mancanti: ${missing_tools[*]}"
    log_info "Esegui: ./prerequisites-testing.sh"
    exit 1
fi

log_success "Testing tools verificati"
log_success "Prerequisiti testing verificati con successo!"
exit 0