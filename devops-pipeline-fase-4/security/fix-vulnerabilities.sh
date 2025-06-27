#!/bin/bash

# =======================================================
# CRM System - Automated Security Vulnerability Fix
# FASE 4: Security Baseline
# =======================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "======================================="
echo "   CRM System - Security Vulnerability Fix"
echo "   FASE 4: Security Baseline"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to fix cross-spawn vulnerability
fix_cross_spawn() {
    log_info "Fixing cross-spawn vulnerability CVE-2024-21538..."
    
    cd "${PROJECT_ROOT}/backend"
    
    # Check current version
    log_info "Current cross-spawn version:"
    npm list cross-spawn 2>/dev/null || log_warn "cross-spawn not found in direct dependencies"
    
    # Update to fixed version
    log_info "Updating cross-spawn to secure version 7.0.5..."
    npm install cross-spawn@7.0.5 --save-exact
    
    # Verify fix
    log_info "Verifying fix..."
    UPDATED_VERSION=$(npm list cross-spawn --depth=0 2>/dev/null | grep cross-spawn | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "not-found")
    
    if [[ "$UPDATED_VERSION" == "7.0.5" ]]; then
        log_info "✅ cross-spawn successfully updated to $UPDATED_VERSION"
        return 0
    else
        log_warn "⚠️ cross-spawn version: $UPDATED_VERSION (may be indirect dependency)"
        
        # Try to force update through package-lock
        log_info "Attempting to force update through package-lock..."
        npm audit fix --force
        
        log_info "Regenerating package-lock.json..."
        rm -f package-lock.json
        npm install
        
        return 0
    fi
}

# Function to setup package-lock if missing
ensure_package_lock() {
    local dir=$1
    local name=$2
    
    cd "$dir"
    
    if [[ ! -f "package-lock.json" ]]; then
        log_warn "No package-lock.json found in $name, creating one..."
        npm install --package-lock-only
        log_info "✅ package-lock.json created for $name"
    else
        log_info "✅ package-lock.json exists for $name"
    fi
}

# Function to update all vulnerable dependencies
fix_all_vulnerabilities() {
    log_info "Running comprehensive vulnerability fix..."
    
    # Backend fixes
    cd "${PROJECT_ROOT}/backend"
    
    # Ensure package-lock exists
    ensure_package_lock "${PROJECT_ROOT}/backend" "backend"
    
    # NPM audit fix
    log_info "Running npm audit fix for backend..."
    npm audit fix || log_warn "Some backend vulnerabilities may remain"
    
    # Force fix for high severity
    log_info "Running npm audit fix --force for backend high severity issues..."
    npm audit fix --force || log_warn "Some backend vulnerabilities may persist"
    
    # Frontend fixes
    cd "${PROJECT_ROOT}/frontend"
    
    # Ensure package-lock exists for frontend
    ensure_package_lock "${PROJECT_ROOT}/frontend" "frontend"
    
    # Fix frontend vulnerabilities
    log_info "Running npm audit fix for frontend..."
    npm audit fix || log_warn "Some frontend vulnerabilities may remain"
    
    log_info "Running npm audit fix --force for frontend high severity issues..."
    npm audit fix --force || log_warn "Some frontend vulnerabilities may persist"
    
    cd "${PROJECT_ROOT}"
}

# Function to verify fixes
verify_fixes() {
    log_info "Verifying security fixes..."
    
    cd "${PROJECT_ROOT}/backend"
    log_info "Backend vulnerability check:"
    npm audit --audit-level=high || log_warn "Some backend vulnerabilities may remain"
    
    cd "${PROJECT_ROOT}/frontend" 
    log_info "Frontend vulnerability check:"
    npm audit --audit-level=high || log_warn "Some frontend vulnerabilities may remain"
    
    cd "${PROJECT_ROOT}"
}

# Function to update package-lock files
update_package_locks() {
    log_info "Updating package-lock.json files..."
    
    # Backend
    cd "${PROJECT_ROOT}/backend"
    if [[ -f package-lock.json ]]; then
        log_info "Updating backend package-lock.json..."
        npm ci --package-lock-only || npm install
    fi
    
    # Frontend
    cd "${PROJECT_ROOT}/frontend"
    if [[ -f package-lock.json ]]; then
        log_info "Updating frontend package-lock.json..."
        npm ci --package-lock-only || npm install
    fi
    
    cd "${PROJECT_ROOT}"
}

# Main execution
main() {
    log_info "Starting automated security vulnerability fix..."
    
    # Check if we're in the right directory
    if [[ ! -f "${PROJECT_ROOT}/backend/package.json" ]]; then
        log_error "Backend package.json not found. Are you in the CRM-System root?"
        exit 1
    fi
    
    if [[ ! -f "${PROJECT_ROOT}/frontend/package.json" ]]; then
        log_error "Frontend package.json not found. Are you in the CRM-System root?"
        exit 1
    fi
    
    # 1. Ensure package-lock files exist
    ensure_package_lock "${PROJECT_ROOT}/backend" "backend"
    ensure_package_lock "${PROJECT_ROOT}/frontend" "frontend"
    
    # 2. Fix specific cross-spawn vulnerability
    fix_cross_spawn
    
    # 3. Fix all other vulnerabilities
    fix_all_vulnerabilities
    
    # 4. Update package locks
    update_package_locks
    
    # 5. Verify fixes
    verify_fixes
    
    log_info "🎉 Security vulnerability fix completed!"
    log_info "📝 Please commit the updated package.json and package-lock.json files"
    log_info "🚀 Rebuild containers to apply fixes: ./devops-pipeline-fase-2/deploy-containers.sh build"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
