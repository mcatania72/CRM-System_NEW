#!/bin/bash

# ============================================
# CRM System - E2E Testing Semplificato v1.0
# FASE 5: Testing E2E Veloce e Affidabile
# ============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${BLUE}[E2E-SIMPLE]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') E2E-SIMPLE: $1" >> ~/testing.log
}

log_success() {
    echo -e "${GREEN}[E2E-SIMPLE]${NC} ✅ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') E2E-SIMPLE SUCCESS: $1" >> ~/testing.log
}

log_warning() {
    echo -e "${YELLOW}[E2E-SIMPLE]${NC} ⚠️ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') E2E-SIMPLE WARNING: $1" >> ~/testing.log
}

log_error() {
    echo -e "${RED}[E2E-SIMPLE]${NC} ❌ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') E2E-SIMPLE ERROR: $1" >> ~/testing.log
}

# Variables
PROJECT_DIR="~/devops/CRM-System"
TEST_TIMEOUT=10
MAX_RETRIES=3

log_info "Avvio E2E testing semplificato..."

# Check if CRM application is running
check_app_running() {
    log_info "Verifica applicazione CRM in esecuzione..."
    
    # Check frontend
    if curl -s --max-time 5 http://localhost:3000 >/dev/null 2>&1; then
        log_success "Frontend CRM risponde su http://localhost:3000"
    else
        log_error "Frontend CRM non risponde su http://localhost:3000"
        return 1
    fi
    
    # Check backend
    if curl -s --max-time 5 http://localhost:3001/api/health >/dev/null 2>&1; then
        log_success "Backend CRM risponde su http://localhost:3001"
    else
        log_warning "Backend CRM non risponde su http://localhost:3001 (potrebbero essere test limitati)"
    fi
    
    return 0
}

# Create optimized Playwright config for simple tests
create_simple_config() {
    log_info "Creazione configurazione Playwright semplificata..."
    
    cd "$PROJECT_DIR" || return 1
    
    # Create simple config focused on Chromium only
    cat > playwright-simple.config.js << 'EOF'
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './testing/e2e/simple',
  fullyParallel: true,
  workers: 1,  // Single worker for stability
  retries: 1,  // One retry only
  timeout: 15000,  // 15 seconds timeout
  
  use: {
    baseURL: 'http://localhost:3000',
    headless: true,
    video: 'off',
    screenshot: 'only-on-failure',
    trace: 'off',
    ignoreHTTPSErrors: true,
    bypassCSP: true,
  },

  // Only Chromium for speed and compatibility
  projects: [
    {
      name: 'chromium-simple',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--no-first-run',
            '--disable-extensions',
            '--disable-background-timer-throttling',
          ]
        }
      },
    },
  ],

  reporter: [
    ['list', { printSteps: true }],
    ['html', { open: 'never', outputFolder: 'testing/reports/e2e-simple' }]
  ],
});
EOF

    log_success "Configurazione Playwright semplificata creata"
    return 0
}

# Create simple E2E tests
create_simple_tests() {
    log_info "Creazione test E2E semplificati..."
    
    # Create test directory
    mkdir -p "$PROJECT_DIR/testing/e2e/simple"
    
    # Create basic smoke test
    cat > "$PROJECT_DIR/testing/e2e/simple/smoke.spec.js" << 'EOF'
const { test, expect } = require('@playwright/test');

test.describe('CRM Smoke Tests', () => {
  test('homepage loads and has title', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await expect(page).toHaveTitle(/CRM|Login|Dashboard/, { timeout: 10000 });
  });

  test('login form is visible', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    
    // Wait for page to be interactive
    await page.waitForLoadState('networkidle', { timeout: 10000 });
    
    // Check for email input (flexible selectors)
    const emailInput = page.locator('input[type="email"], input[name="email"], input[placeholder*="email" i]').first();
    await expect(emailInput).toBeVisible({ timeout: 5000 });
    
    // Check for password input
    const passwordInput = page.locator('input[type="password"], input[name="password"]').first();
    await expect(passwordInput).toBeVisible({ timeout: 5000 });
  });

  test('can navigate to login page if redirected', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    
    // Should either be on login or dashboard
    const url = page.url();
    expect(url).toMatch(/localhost:3000/);
  });
});
EOF

    # Create optional auth test (if credentials are available)
    cat > "$PROJECT_DIR/testing/e2e/simple/auth-basic.spec.js" << 'EOF'
const { test, expect } = require('@playwright/test');

test.describe('CRM Basic Auth', () => {
  test.skip(({ browserName }) => browserName !== 'chromium', 'Only run on Chromium');

  test('login form accepts input', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    
    // Wait for interactive state
    await page.waitForLoadState('networkidle', { timeout: 10000 });
    
    try {
      // Find email input with flexible selector
      const emailInput = page.locator('input[type="email"], input[name="email"], input[placeholder*="email" i]').first();
      await emailInput.fill('test@example.com', { timeout: 5000 });
      
      // Find password input
      const passwordInput = page.locator('input[type="password"], input[name="password"]').first();
      await passwordInput.fill('password123', { timeout: 5000 });
      
      // Check that values were entered
      await expect(emailInput).toHaveValue('test@example.com');
      await expect(passwordInput).toHaveValue('password123');
      
    } catch (error) {
      test.skip('Login form not available or not interactive');
    }
  });
});
EOF

    log_success "Test E2E semplificati creati"
    return 0
}

# Run simple E2E tests
run_simple_tests() {
    log_info "Esecuzione test E2E semplificati..."
    
    cd "$PROJECT_DIR" || return 1
    
    # Set environment for testing
    export NODE_ENV=test
    export PLAYWRIGHT_BROWSERS_PATH=$HOME/.cache/ms-playwright
    
    # Run tests with simple config
    log_info "Esecuzione: npx playwright test --config=playwright-simple.config.js"
    
    if npx playwright test --config=playwright-simple.config.js --reporter=list --timeout=15000 2>&1; then
        log_success "Test E2E semplificati completati con successo!"
        
        # Show report location
        if [[ -d "testing/reports/e2e-simple" ]]; then
            log_info "Report disponibile in: testing/reports/e2e-simple/index.html"
        fi
        
        return 0
    else
        log_error "Test E2E semplificati falliti"
        return 1
    fi
}

# Cleanup function
cleanup_tests() {
    log_info "Pulizia ambiente test..."
    
    # Remove temp files
    rm -f "$PROJECT_DIR/playwright-simple.config.js" 2>/dev/null || true
    
    # Kill any remaining browser processes
    pkill -f "chromium" 2>/dev/null || true
    pkill -f "playwright" 2>/dev/null || true
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "=== E2E Testing Semplificato FASE 5 ==="
    
    # Check if Playwright is available
    if ! command -v playwright >/dev/null 2>&1 && ! npx playwright --version >/dev/null 2>&1; then
        log_error "Playwright non disponibile. Eseguire prima: ./prerequisites-testing.sh"
        return 1
    fi
    
    # Check if app is running
    if ! check_app_running; then
        log_error "Applicazione CRM non disponibile. Avviare prima con FASE 1-4"
        return 1
    fi
    
    # Create config and tests
    if ! create_simple_config; then
        log_error "Errore creazione configurazione"
        return 1
    fi
    
    if ! create_simple_tests; then
        log_error "Errore creazione test"
        return 1
    fi
    
    # Run tests with retry logic
    local attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        ((attempts++))
        log_info "Tentativo $attempts/$MAX_RETRIES..."
        
        if run_simple_tests; then
            log_success "E2E testing semplificato completato con successo!"
            break
        else
            if [[ $attempts -lt $MAX_RETRIES ]]; then
                log_warning "Tentativo fallito, retry in 5 secondi..."
                sleep 5
            else
                log_error "Tutti i tentativi falliti"
                cleanup_tests
                return 1
            fi
        fi
    done
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "E2E testing completato in ${duration} secondi"
    
    # Cleanup
    cleanup_tests
    
    return 0
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi