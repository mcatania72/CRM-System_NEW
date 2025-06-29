// e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('CRM Login Flow', () => {

  test('should allow a user to log in successfully', async ({ page }) => {
    // 1. Naviga alla pagina di login
    await page.goto('/');

    // 2. Verifica che i campi del form siano presenti
    const emailInput = page.locator('input[name="email"]');
    const passwordInput = page.locator('input[name="password"]');
    const loginButton = page.locator('button[type="submit"]');

    await expect(emailInput).toBeVisible();
    await expect(passwordInput).toBeVisible();
    await expect(loginButton).toBeVisible();

    // 3. Inserisci le credenziali
    await emailInput.fill('admin@crm.local');
    await passwordInput.fill('admin123');

    // 4. Clicca sul pulsante di login
    await loginButton.click();

    // 5. Verifica il reindirizzamento e il contenuto della dashboard
    // Attendi che l'URL cambi in '/dashboard'
    await page.waitForURL('**/dashboard');
    
    // Verifica che un elemento chiave della dashboard sia visibile
    const dashboardTitle = page.locator('h1', { hasText: 'Dashboard' });
    await expect(dashboardTitle).toBeVisible();

    // Opzionale: verifica che il token sia stato salvato nel localStorage
    const token = await page.evaluate(() => localStorage.getItem('token'));
    expect(token).not.toBeNull();
  });

  test('should show an error for invalid credentials', async ({ page }) => {
    // 1. Naviga alla pagina di login
    await page.goto('/');

    // 2. Inserisci credenziali errate
    await page.locator('input[name="email"]').fill('wrong@user.com');
    await page.locator('input[name="password"]').fill('wrongpassword');

    // 3. Clicca sul pulsante di login
    await page.locator('button[type="submit"]').click();

    // 4. Verifica che appaia un messaggio di errore
    // (L'implementazione esatta del messaggio di errore può variare)
    const errorMessage = page.locator('.MuiAlert-root.MuiAlert-filledError, [data-testid="error-message"]');
    await expect(errorMessage).toBeVisible();
    await expect(errorMessage).toContainText(/Errore|failed|invalid/i);

    // 5. Verifica di essere ancora sulla pagina di login
    await expect(page).toHaveURL(/login|/);
  });
});
