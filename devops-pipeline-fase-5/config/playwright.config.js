// Playwright Configuration for E2E Testing
// FASE 5: Enterprise Testing Strategy

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  // Test directory
  testDir: './testing/e2e',
  
  // Parallel execution
  fullyParallel: true,
  
  // Worker configuration
  workers: process.env.CI ? 1 : 2,
  
  // Retry configuration
  retries: process.env.CI ? 2 : 1,
  
  // Test timeout
  timeout: 30000,
  
  // Global test configuration
  use: {
    // Base URL
    baseURL: 'http://localhost:3100',
    
    // Browser configuration
    headless: true,
    
    // Tracing and debugging
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Navigation timeout
    navigationTimeout: 30000,
    
    // Action timeout
    actionTimeout: 10000,
    
    // Ignore HTTPS errors
    ignoreHTTPSErrors: true
  },
  
  // Test projects for different browsers
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage'
          ]
        }
      }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    }
  ],
  
  // Reporter configuration
  reporter: [
    ['list'],
    ['html', { 
      outputFolder: '../testing-workspace/reports/playwright',
      open: 'never'
    }],
    ['json', {
      outputFile: '../testing-workspace/reports/playwright-results.json'
    }]
  ],
  
  // Output directory
  outputDir: '../testing-workspace/artifacts/playwright',
  
  // Web server configuration
  webServer: {
    command: 'echo "Using existing development server"',
    url: 'http://localhost:3100',
    reuseExistingServer: true,
    timeout: 30000
  }
});