#!/bin/bash

# ============================================
# Deploy Testing - Environment Setup Module
# FASE 5: Setup ambiente testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_env() {
    echo -e "${BLUE}[ENVIRONMENT]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ENVIRONMENT: $1" >> ~/deploy-testing.log
}

log_env "Setup testing environment..."

# Create testing directories
TEST_DIRS=(
    "$HOME/testing-workspace"
    "$HOME/testing-workspace/reports"
    "$HOME/testing-workspace/coverage"
    "$HOME/testing-workspace/screenshots"
    "$HOME/testing-workspace/videos"
    "$HOME/testing-workspace/artifacts"
)

for dir in "${TEST_DIRS[@]}"; do
    mkdir -p "$dir"
done

log_env "✅ Testing directories created"

# Setup test database (copy from main)
TEST_DB="$HOME/testing-workspace/test.db"
MAIN_DB="$HOME/devops/CRM-System/backend/database.db"

if [[ -f "$MAIN_DB" ]]; then
    if [[ ! -f "$TEST_DB" ]]; then
        cp "$MAIN_DB" "$TEST_DB"
        log_env "✅ Test database creato"
    else
        log_env "✅ Test database già esistente"
    fi
else
    log_env "⚠️ Database principale non trovato, creando vuoto"
    touch "$TEST_DB"
fi

# Setup test data
log_env "Setup test data..."
if [[ -f "../scripts/setup-test-data.sh" ]]; then
    bash "../scripts/setup-test-data.sh"
else
    log_env "⚠️ Script setup test data non trovato"
fi

# Create .env for testing
cat > "$HOME/testing-workspace/.env.testing" << EOF
# Testing Environment Configuration
NODE_ENV=test
TEST_DB_PATH=$TEST_DB
BACKEND_URL=http://localhost:3101
FRONTEND_URL=http://localhost:3100
TEST_TIMEOUT=30000
PORT_BACKEND_TEST=3101
PORT_FRONTEND_TEST=3100
EOF

log_env "✅ Environment testing configurato"
exit 0