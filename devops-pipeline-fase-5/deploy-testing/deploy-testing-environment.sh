#!/bin/bash

# =======================================
#   Deploy Testing - Environment Setup
#   FASE 5: Step 2
# =======================================

set -e

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
mkdir -p "$HOME/devops/CRM-System/testing/data"
mkdir -p "$HOME/devops/CRM-System/testing/reports"
mkdir -p "$HOME/devops/CRM-System/testing/screenshots"
mkdir -p "$HOME/devops/CRM-System/testing/artifacts"

log_success "Testing directories created"

# Setup test database
if [ ! -f "$TEST_DATABASE" ]; then
    log_info "Creazione test database..."
    if [ -f "$HOME/devops/CRM-System/backend/database.sqlite" ]; then
        cp "$HOME/devops/CRM-System/backend/database.sqlite" "$TEST_DATABASE"
        log_success "Test database copiato da database originale"
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
    bash "$SCRIPT_DIR/../scripts/setup-test-data.sh"
else
    log_warning "Script setup-test-data.sh non trovato"
fi

log_success "Testing environment configurato con successo!"