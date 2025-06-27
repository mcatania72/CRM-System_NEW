#!/bin/bash

# =======================================
#   Deploy Testing - Environment Setup
#   FASE 5: Step 2 (FIXED - No set -e)
# =======================================

# NO set -e per gestire meglio gli errori

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[ENVIRONMENT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ENVIRONMENT]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[ENVIRONMENT]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[ENVIRONMENT]${NC} ⚠️ $1"
}

# Testing configuration
TEST_DATABASE="$HOME/devops/CRM-System/testing/test.sqlite"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Setup testing environment..."

# Create testing directories
if mkdir -p "$HOME/devops/CRM-System/testing/data" "$HOME/devops/CRM-System/testing/reports" "$HOME/devops/CRM-System/testing/screenshots" "$HOME/devops/CRM-System/testing/artifacts"; then
    log_success "Testing directories created"
else
    log_error "Failed to create testing directories"
    exit 1
fi

# Setup test database
if [ ! -f "$TEST_DATABASE" ]; then
    log_info "Creazione test database..."
    if [ -f "$HOME/devops/CRM-System/backend/database.sqlite" ]; then
        if cp "$HOME/devops/CRM-System/backend/database.sqlite" "$TEST_DATABASE"; then
            log_success "Test database copiato da database originale"
        else
            log_warning "Fallback: creo database vuoto"
            touch "$TEST_DATABASE"
        fi
    else
        log_warning "Database originale non trovato, creo database vuoto"
        touch "$TEST_DATABASE"
    fi
else
    log_success "Test database già esistente"
fi

# Setup test data
if [ -f "$SCRIPT_DIR/../scripts/setup-test-data.sh" ]; then
    log_info "Setup test data..."
    if bash "$SCRIPT_DIR/../scripts/setup-test-data.sh"; then
        log_success "Test data setup completato"
    else
        log_warning "Test data setup fallito, continuo comunque"
    fi
else
    log_warning "Script setup-test-data.sh non trovato"
fi

log_success "Testing environment configurato con successo!"
exit 0