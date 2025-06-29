#!/bin/bash
# prerequisites-e2e.sh (Idempotent Version)
# Script per installare le dipendenze per i test End-to-End con Playwright.
# FASE 5: Testing Avanzato

set -e

# Colori per output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funzioni di logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_info "Inizio installazione prerequisiti per Test E2E..."

# Naviga alla directory del frontend
FRONTEND_DIR="$(dirname "$0")/../frontend"
cd "$FRONTEND_DIR"
log_info "Verifica dipendenze nella directory: $(pwd)"

# 1. Controlla e installa le dipendenze npm di Playwright
if ! npm list @playwright/test >/dev/null 2>&1; then
    log_info "Pacchetto @playwright/test non trovato. Installazione in corso..."
    npm install --save-dev @playwright/test
    log_success "Pacchetto Playwright installato."
else
    log_success "Pacchetto @playwright/test già installato."
fi

# 2. Controlla e installa i browser necessari per Playwright
# Playwright stesso non offre un modo semplice per verificare se i browser sono
# già installati, ma il comando `install` è idempotente: non riscarica
# i file se sono già presenti e aggiornati.
log_info "Verifica e installazione dei browser per Playwright (Chromium, Firefox, WebKit)..."
npx playwright install --with-deps
log_success "Browser verificati e/o installati con successo."

log_success "Prerequisiti per i test E2E installati correttamente."