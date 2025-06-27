#!/bin/bash

# =======================================
#   Deploy Testing - Cleanup
#   FASE 5: Cleanup Step
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[CLEANUP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[CLEANUP]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[CLEANUP]${NC} ❌ $1"
}

log_info "Cleanup testing artifacts..."

# Remove old reports
rm -rf "$HOME/devops/CRM-System/testing/reports/*" 2>/dev/null || true
log_success "Reports puliti"

# Remove screenshots
rm -rf "$HOME/devops/CRM-System/testing/screenshots/*" 2>/dev/null || true
log_success "Screenshots puliti"

# Remove artifacts
rm -rf "$HOME/devops/CRM-System/testing/artifacts/*" 2>/dev/null || true
log_success "Artifacts puliti"

# Clean logs
rm -f "$HOME/backend-testing.log" "$HOME/frontend-testing.log" 2>/dev/null || true
log_success "Logs puliti"

log_success "Testing artifacts puliti con successo!"