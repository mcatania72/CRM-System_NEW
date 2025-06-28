#!/bin/bash

# ============================================
# Test Advanced - E2E Tests Module
# FASE 5: End-to-end testing con Playwright
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_e2e() {
    echo -e "${BLUE}[E2E]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') E2E: $1" >> ~/test-advanced.log
}

log_e2e "Esecuzione End-to-End Tests..."

# Check if Playwright is available
if ! command -v playwright >/dev/null 2>&1 && ! npx playwright --version >/dev/null 2>&1; then
    log_e2e "❌ Playwright non disponibile"
    exit 1
fi

# Create Playwright config for testing
log_e2e "Creazione configurazione Playwright..."
cd "$HOME/devops/CRM-System" || exit 1

cat > playwright.config.js << 'EOF'
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './testing/e2e',
  fullyParallel: true,
  workers: 2,
  retries: 1,
  timeout: 30000,
  
  use: {
    baseURL: 'http://localhost:3100',
    headless: true,
    video: 'off',
    screenshot: 'only-on-failure',
    trace: 'off',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  reporter: [
    ['list'],
    ['html', { outputFolder: 'testing/reports/e2e', open: 'never' }]
  ],
});
EOF

# Create basic E2E tests
log_e2e "Creazione test E2E di base..."
mkdir -p testing/e2e

cat > testing/e2e/basic.spec.js << 'EOF'
const { test, expect } = require('@playwright/test');

test.describe('CRM Application E2E Tests', () => {
  test('homepage loads', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/CRM|Login|Dashboard/);
  });

  test('login page has form elements', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('input[type="email"], input[name="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"], input[name="password"]')).toBeVisible();
  });

  test('can attempt login', async ({ page }) => {
    await page.goto('/');
    
    const emailInput = page.locator('input[type="email"], input[name="email"]').first();
    const passwordInput = page.locator('input[type="password"], input[name="password"]').first();
    
    await emailInput.fill('admin@crm.local');
    await passwordInput.fill('admin123');
    
    const submitButton = page.locator('button[type="submit"], button').first();
    await submitButton.click();
    
    // Wait for navigation or error message
    await page.waitForTimeout(3000);
  });
});
EOF

# Run Playwright E2E tests
log_e2e "Esecuzione Playwright E2E tests..."
if npx playwright test 2>&1 | tee "$HOME/testing-workspace/reports/e2e-tests.log"; then
    log_e2e "✅ E2E Tests: PASSED ✅"
    E2E_SUCCESS=true
else
    log_e2e "❌ E2E Tests: FAILED ❌"
    log_e2e "Vedi: $HOME/testing-workspace/reports/e2e-tests.log"
    E2E_SUCCESS=false
fi

# Generate E2E test report
log_e2e "Generazione report E2E tests..."
cat > "$HOME/testing-workspace/reports/e2e-summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "e2e_tests": $E2E_SUCCESS,
  "overall": $E2E_SUCCESS
}
EOF

if [[ "$E2E_SUCCESS" == true ]]; then
    log_e2e "✅ E2E tests completati con successo!"
    exit 0
else
    log_e2e "❌ E2E tests falliti"
    exit 1
fi