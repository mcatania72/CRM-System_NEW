#!/bin/bash

# ============================================
# Deploy Testing - Prerequisites Module
# FASE 5: Verifica prerequisiti testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_prerequisites() {
    echo -e "${BLUE}[PREREQUISITES]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') PREREQUISITES: $1" >> ~/deploy-testing.log
}

log_prerequisites "Verifica prerequisiti testing environment..."

# Check previous phases
PHASES=("devops-pipeline-fase-1" "devops-pipeline-fase-2" "devops-pipeline-fase-3" "devops-pipeline-fase-4")
for phase in "${PHASES[@]}"; do
    if [[ -d "../$phase" ]]; then
        log_prerequisites "✅ $phase trovata"
    else
        log_prerequisites "⚠️ $phase non trovata"
    fi
done

# Check testing tools
TOOLS=("node" "npm" "docker")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_prerequisites "✅ $tool disponibile"
    else
        log_prerequisites "❌ $tool non disponibile"
        exit 1
    fi
done

# Check testing-specific tools
if npm list -g jest >/dev/null 2>&1 || command -v jest >/dev/null 2>&1; then
    log_prerequisites "✅ Jest disponibile"
else
    log_prerequisites "⚠️ Jest non trovato (opzionale)"
fi

if command -v playwright >/dev/null 2>&1 || npx playwright --version >/dev/null 2>&1; then
    log_prerequisites "✅ Playwright disponibile"
else
    log_prerequisites "⚠️ Playwright non trovato (opzionale)"
fi

log_prerequisites "✅ Testing tools verificati"

# Check if base application is running
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    log_prerequisites "✅ Base application (3000) disponibile"
else
    log_prerequisites "⚠️ Base application non in esecuzione"
fi

if curl -s http://localhost:3001 >/dev/null 2>&1; then
    log_prerequisites "✅ Base backend (3001) disponibile"
else
    log_prerequisites "⚠️ Base backend non in esecuzione"
fi

log_prerequisites "✅ Prerequisiti testing verificati con successo!"
exit 0