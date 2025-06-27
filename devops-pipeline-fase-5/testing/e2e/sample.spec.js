// Sample E2E Test for CRM System
// FASE 5: Enterprise Testing Strategy

const { test, expect } = require('@playwright/test');

test.describe('CRM System E2E Sample Tests', () => {
  test('should load application', async ({ page }) => {
    await page.goto('/');
    
    // Basic check that something loads
    const body = await page.locator('body');
    await expect(body).toBeVisible();
  });
  
  test('should be responsive', async ({ page }) => {
    await page.goto('/');
    
    // Test mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.waitForTimeout(1000);
    
    // Test desktop viewport
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForTimeout(1000);
    
    const body = await page.locator('body');
    await expect(body).toBeVisible();
  });
});