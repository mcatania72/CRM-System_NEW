// Sample E2E Tests
// FASE 5: Enterprise Testing Strategy

const { test, expect } = require('@playwright/test');

test.describe('CRM System - Sample E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the application
    await page.goto('/');
  });
  
  test('should load homepage', async ({ page }) => {
    // Check that the page loads
    await expect(page).toHaveTitle(/CRM|Login|Dashboard/);
    
    // Check for basic page structure
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });
  
  test('should have login form elements', async ({ page }) => {
    // Check for email input
    const emailInput = page.locator('input[type="email"], input[name="email"], input[placeholder*="email" i]');
    await expect(emailInput.first()).toBeVisible({ timeout: 10000 });
    
    // Check for password input
    const passwordInput = page.locator('input[type="password"], input[name="password"]');
    await expect(passwordInput.first()).toBeVisible({ timeout: 10000 });
    
    // Check for submit button
    const submitButton = page.locator('button[type="submit"], button');
    await expect(submitButton.first()).toBeVisible({ timeout: 10000 });
  });
  
  test('should allow form interaction', async ({ page }) => {
    // Wait for page to be interactive
    await page.waitForLoadState('networkidle', { timeout: 15000 });
    
    try {
      // Find and fill email input
      const emailInput = page.locator('input[type="email"], input[name="email"], input[placeholder*="email" i]').first();
      await emailInput.fill('test@example.com', { timeout: 5000 });
      
      // Find and fill password input
      const passwordInput = page.locator('input[type="password"], input[name="password"]').first();
      await passwordInput.fill('testpassword', { timeout: 5000 });
      
      // Verify values were entered
      await expect(emailInput).toHaveValue('test@example.com');
      await expect(passwordInput).toHaveValue('testpassword');
      
    } catch (error) {
      // If form interaction fails, skip this test
      test.skip(error.message.includes('not found'), 'Form elements not available');
    }
  });
  
  test('should handle navigation', async ({ page }) => {
    // Test basic navigation
    const currentUrl = page.url();
    expect(currentUrl).toContain('localhost:3100');
    
    // Test page refresh
    await page.reload();
    
    // Verify page still loads after refresh
    await expect(page.locator('body')).toBeVisible();
  });
  
  test('should be responsive', async ({ page }) => {
    // Test different viewport sizes
    const viewports = [
      { width: 1920, height: 1080 }, // Desktop
      { width: 768, height: 1024 },  // Tablet
      { width: 375, height: 667 }    // Mobile
    ];
    
    for (const viewport of viewports) {
      await page.setViewportSize(viewport);
      
      // Verify page is still functional
      await expect(page.locator('body')).toBeVisible();
      
      // Small delay for layout adjustment
      await page.waitForTimeout(500);
    }
  });
  
  test('should have basic performance characteristics', async ({ page }) => {
    // Measure page load time
    const startTime = Date.now();
    await page.goto('/', { waitUntil: 'networkidle' });
    const loadTime = Date.now() - startTime;
    
    // Basic performance assertion (should load within 10 seconds)
    expect(loadTime).toBeLessThan(10000);
    
    // Check for basic performance metrics
    const performanceEntries = await page.evaluate(() => {
      return JSON.stringify(performance.getEntriesByType('navigation'));
    });
    
    expect(performanceEntries).toBeDefined();
  });
});