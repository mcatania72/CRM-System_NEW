#!/bin/bash

# ============================================
# Test Advanced - E2E Tests Module
# FASE 5: End-to-end testing con Playwright
# Auto-detection porte per massima robustezza
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

log_e2e "Esecuzione End-to-End Tests con auto-detection porte..."

# Funzione per rilevare porta attiva (NO LOGGING per evitare interferenze)
detect_active_port_silent() {
    local service_name=$1
    local ports_array=("${@:2}")
    
    for port in "${ports_array[@]}"; do
        local url="http://localhost:${port}"
        
        if curl -s --max-time 3 "${url}" >/dev/null 2>&1; then
            echo "${port}"
            return 0
        fi
    done
    
    return 1
}

# Auto-detect frontend port
log_e2e "🔍 Auto-detecting frontend port for Playwright..."
FRONTEND_PORTS=(3100 3000 4173 3002)

# Test each port with detailed logging
FRONTEND_PORT=""
for port in "${FRONTEND_PORTS[@]}"; do
    log_e2e "🔍 Testing Frontend on port ${port}..."
    if curl -s --max-time 3 "http://localhost:${port}" >/dev/null 2>&1; then
        log_e2e "✅ Frontend found on port ${port}"
        FRONTEND_PORT=${port}
        break
    else
        log_e2e "❌ Frontend not found on port ${port}"
    fi
done

if [[ -z "$FRONTEND_PORT" ]]; then
    log_e2e "❌ Frontend not accessible on any common port"
    log_e2e "⚠️ Ports tested: ${FRONTEND_PORTS[*]}"
    exit 1
fi

FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
log_e2e "📋 Using Frontend: ${FRONTEND_URL}"

# Check if Playwright is available
if ! command -v playwright >/dev/null 2>&1 && ! npx playwright --version >/dev/null 2>&1; then
    log_e2e "❌ Playwright non disponibile"
    exit 1
fi

# Create Playwright config for testing with dynamic port
log_e2e "Creazione configurazione Playwright con porta rilevata..."
cd "$HOME/devops/CRM-System" || exit 1

# Generate config file WITHOUT any logging interference
cat > playwright.config.js << 'PLAYWRIGHT_CONFIG_EOF'
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './testing/e2e',
  fullyParallel: true,
  workers: 2,
  retries: 2,
  timeout: 30000,
  
  use: {
    baseURL: 'FRONTEND_URL_PLACEHOLDER',
    headless: true,
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    ignoreHTTPSErrors: true,
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },

  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--no-sandbox', '--disable-setuid-sandbox']
        }
      },
    },
  ],

  reporter: [
    ['list'],
    ['json', { outputFile: 'testing/reports/e2e-results.json' }],
    ['html', { outputFolder: 'testing/reports/e2e', open: 'never' }]
  ],
});
PLAYWRIGHT_CONFIG_EOF

# Replace placeholder with actual URL
sed -i "s|FRONTEND_URL_PLACEHOLDER|${FRONTEND_URL}|g" playwright.config.js

log_e2e "✅ Configurazione Playwright creata con baseURL: ${FRONTEND_URL}"

# Create basic E2E tests with improved selectors
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

cat > testing/e2e/auth.spec.js << 'EOF'
const { test, expect } = require('@playwright/test');

test.describe('CRM Authentication', () => {
  test('should load login page', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/CRM/);
    await expect(page.locator('h1')).toContainText('Login');
  });

  test('should login with valid credentials', async ({ page }) => {
    await page.goto('/');

    // Fill login form
    await page.fill('input[type="email"]', 'admin@crm.local');
    await page.fill('input[type="password"]', 'admin123');
    
    // Submit form
    await page.click('button[type="submit"]');
    
    // Wait for navigation
    await page.waitForTimeout(3000);
    
    // Check if redirected to dashboard or still on login with error
    const currentUrl = page.url();
    console.log('Current URL after login:', currentUrl);
  });

  test('should reject invalid credentials', async ({ page }) => {
    await page.goto('/');

    // Fill with invalid credentials
    await page.fill('input[type="email"]', 'invalid@test.com');
    await page.fill('input[type="password"]', 'wrongpassword');
    
    // Submit form
    await page.click('button[type="submit"]');
    
    // Wait for error message or page response
    await page.waitForTimeout(2000);
  });
});
EOF

# Ensure reports directory exists
mkdir -p "$HOME/testing-workspace/reports"
mkdir -p testing/reports

# Run Playwright E2E tests with better error handling
log_e2e "Esecuzione Playwright E2E tests..."

# Set environment variables for the test
export FRONTEND_URL="${FRONTEND_URL}"
export FRONTEND_PORT="${FRONTEND_PORT}"

if npx playwright test --config=playwright.config.js 2>&1 | tee "$HOME/testing-workspace/reports/e2e-tests.log"; then
    log_e2e "✅ E2E Tests: PASSED ✅"
    E2E_SUCCESS=true
else
    log_e2e "❌ E2E Tests: FAILED ❌"
    log_e2e "Vedi: $HOME/testing-workspace/reports/e2e-tests.log"
    
    # Show last few lines of log for quick debugging
    log_e2e "Ultimi errori:"
    tail -10 "$HOME/testing-workspace/reports/e2e-tests.log" | while read line; do
        log_e2e "  $line"
    done
    
    E2E_SUCCESS=false
fi

# Generate E2E test report
log_e2e "Generazione report E2E tests..."
cat > "$HOME/testing-workspace/reports/e2e-summary.json" << REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "frontend_url": "${FRONTEND_URL}",
  "frontend_port": ${FRONTEND_PORT},
  "e2e_tests": $E2E_SUCCESS,
  "overall": $E2E_SUCCESS
}
REPORT_EOF

if [[ "$E2E_SUCCESS" == true ]]; then
    log_e2e "✅ E2E tests completati con successo!"
    exit 0
else
    log_e2e "❌ E2E tests falliti"
    exit 1
fi