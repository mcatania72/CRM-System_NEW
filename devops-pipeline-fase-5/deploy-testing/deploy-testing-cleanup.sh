#!/bin/bash

# ============================================
# Deploy Testing - Cleanup Module
# FASE 5: Pulizia ambiente testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_cleanup() {
    echo -e "${BLUE}[CLEANUP]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') CLEANUP: $1" >> ~/deploy-testing.log
}

log_cleanup "Pulizia ambiente testing..."

# Stop services first
bash "$(dirname "$0")/deploy-testing-stop-services.sh"

# Clean testing workspace
if [[ -d "$HOME/testing-workspace" ]]; then
    log_cleanup "Pulizia testing workspace..."
    rm -rf "$HOME/testing-workspace/reports"/*
    rm -rf "$HOME/testing-workspace/coverage"/*
    rm -rf "$HOME/testing-workspace/screenshots"/*
    rm -rf "$HOME/testing-workspace/videos"/*
    rm -rf "$HOME/testing-workspace/artifacts"/*
    log_cleanup "✅ Workspace pulito"
fi

# Clean log files
log_cleanup "Pulizia log files..."
LOG_FILES=("backend-testing.log" "frontend-testing.log" "test-advanced.log")
for log_file in "${LOG_FILES[@]}"; do
    if [[ -f "$HOME/$log_file" ]]; then
        > "$HOME/$log_file"  # Truncate log
        log_cleanup "✅ $log_file pulito"
    fi
done

# Clean temporary files
log_cleanup "Pulizia file temporanei..."
rm -f "$HOME/backend-testing.pid"
rm -f "$HOME/frontend-testing.pid"
rm -f "$HOME/testing-workspace/.env.testing"

# Clean npm cache testing
log_cleanup "Pulizia cache npm testing..."
npm cache clean --force >/dev/null 2>&1 || true

log_cleanup "✅ Pulizia completata con successo!"
exit 0