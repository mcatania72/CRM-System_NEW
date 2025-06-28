const { defineConfig, devices } = require('@playwright/test');

/**
 * Configurazione Playwright con auto-detection porte
 * FASE 5: Enterprise Testing Strategy
 */

// Auto-detect della porta frontend attiva
function detectFrontendPort() {
  const ports = [3100, 3000, 4173, 3002];
  const http = require('http');
  
  for (const port of ports) {
    try {
      const req = http.request({
        hostname: 'localhost',
        port: port,
        timeout: 1000,
        method: 'HEAD'
      }, (res) => {
        return port;
      });
      req.on('error', () => {});
      req.end();
      // Fallback a porta più comune se detection fallisce
      return port;
    } catch (e) {
      continue;
    }
  }
  return 3000; // Default fallback
}

// Configurazione con porte dinamiche
const FRONTEND_PORT = process.env.FRONTEND_PORT || detectFrontendPort();
const BACKEND_PORT = process.env.BACKEND_PORT || 3101;

module.exports = defineConfig({
  testDir: './testing/e2e',
  outputDir: './testing/reports/test-results',
  
  /* Configurazione test */
  timeout: 30 * 1000, // 30 secondi per test
  expect: {
    timeout: 5000 // 5 secondi per assertions
  },
  
  /* Fail fast in CI */
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 1 : 2,
  
  /* Reporter configuration */
  reporter: [
    ['html', { outputFolder: './testing/reports/e2e' }],
    ['json', { outputFile: './testing/reports/e2e-results.json' }],
    ['list']
  ],
  
  /* Global setup */
  use: {
    /* Base URL con auto-detection */
    baseURL: `http://localhost:${FRONTEND_PORT}`,
    
    /* Browser configuration */
    headless: true,
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    
    /* Timeouts */
    actionTimeout: 10000,
    navigationTimeout: 30000,
    
    /* Trace */
    trace: 'retain-on-failure',
  },

  /* Environment variables for tests */
  globalSetup: require.resolve('./testing/e2e/global-setup.js'),
  
  /* Project configurations */
  projects: [
    {
      name: 'chromium-fast',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--no-sandbox', '--disable-setuid-sandbox']
        }
      },
      testMatch: ['**/auth.spec.js', '**/basic.spec.js']
    },
    
    {
      name: 'firefox-essential',
      use: { ...devices['Desktop Firefox'] },
      testMatch: ['**/auth.spec.js']
    },
    
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
      testMatch: ['**/basic.spec.js']
    }
  ],

  /* Local dev server setup */
  webServer: [
    {
      command: `curl -f http://localhost:${FRONTEND_PORT} || echo "Frontend not ready"`,
      port: FRONTEND_PORT,
      timeout: 5000,
      reuseExistingServer: true
    },
    {
      command: `curl -f http://localhost:${BACKEND_PORT}/api/health || echo "Backend not ready"`,
      port: BACKEND_PORT,
      timeout: 5000,
      reuseExistingServer: true
    }
  ]
});