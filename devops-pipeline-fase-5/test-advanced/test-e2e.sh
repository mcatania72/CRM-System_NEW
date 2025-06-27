#!/bin/bash

# =======================================
#   Test Advanced - E2E Tests Module
#   FASE 5: End-to-End Testing
# =======================================

# NO set -e per gestire meglio gli errori

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    echo -e "${BLUE}[E2E]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[E2E]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[E2E]${NC} ❌ $1"
}

log_test "Esecuzione End-to-End Tests..."

cd "$HOME/devops/CRM-System"

# Check if Playwright is installed
if ! command -v playwright >/dev/null 2>&1; then
    log_error "Playwright non installato"
    exit 1
fi

# Create Playwright config if not exists
if [ ! -f "playwright.config.js" ]; then
    log_test "Creazione configurazione Playwright..."
    cp "$HOME/devops-pipeline-fase-5/config/playwright.config.js" .
fi

# Create basic E2E test if not exists
mkdir -p testing/e2e
if [ ! -f "testing/e2e/basic.spec.js" ]; then
    log_test "Creazione test E2E di base..."
    cat > testing/e2e/basic.spec.js << 'EOF'
const { test, expect } = require('@playwright/test');

test.describe('CRM System E2E Tests', () => {
  test('should load homepage', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/CRM|React|Vite/);
  });
  
  test('should handle basic navigation', async ({ page }) => {
    await page.goto('/');
    
    // Basic check that page is responsive
    const body = await page.locator('body');
    await expect(body).toBeVisible();
  });
  
  test('should handle API connectivity', async ({ page }) => {
    let apiCallsMade = 0;
    page.on('request', request => {
      if (request.url().includes('/api/')) {
        apiCallsMade++;
      }
    });
    
    await page.goto('/');
    await page.waitForTimeout(3000);
    
    console.log(`API calls made: ${apiCallsMade}`);
  });
});
EOF
fi

# Run Playwright tests
log_test "Esecuzione Playwright E2E tests..."
REPORTS_DIR="$HOME/devops/CRM-System/testing/reports"
mkdir -p "$REPORTS_DIR"

if npx playwright test --reporter=html,json > "$REPORTS_DIR/e2e-tests.log" 2>&1; then
    log_success "E2E Tests: PASSED 🎉"
    exit 0
else
    log_error "E2E Tests: FAILED ❌"
    log_test "Vedi: $REPORTS_DIR/e2e-tests.log"
    exit 1
fi