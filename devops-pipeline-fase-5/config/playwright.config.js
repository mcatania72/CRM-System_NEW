// Playwright Configuration for CRM System
// FASE 5: Enterprise Testing Strategy

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  // Test directory
  testDir: './testing/e2e',
  
  // Timeout settings
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  
  // Test execution settings
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  
  // Reporter configuration
  reporter: [
    ['html', { 
      outputFolder: './testing/reports/playwright-report',
      open: 'never'
    }],
    ['json', { 
      outputFile: './testing/reports/playwright-results.json' 
    }]
  ],
  
  // Global test settings
  use: {
    baseURL: 'http://localhost:3100',
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  
  // Browser projects
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    }
  ]
});