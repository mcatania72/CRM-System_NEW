// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Directory dove si trovano i test E2E
  testDir: './e2e',

  // Esegui i test in parallelo in CI
  fullyParallel: true,

  // Riprova in caso di fallimento in CI
  retries: process.env.CI ? 2 : 0,

  // Numero di processi paralleli da usare
  workers: process.env.CI ? 1 : undefined,

  // Reporter per i risultati dei test
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'playwright-report/results.json' }]
  ],

  // Configurazione globale per tutti i test
  use: {
    // URL di base per l'applicazione. Verrà usato da azioni come `page.goto('/')`.
    // La porta 4000 è quella esposta dal nostro container frontend.
    baseURL: 'http://localhost:4000',

    // Cattura screenshot e video solo in caso di fallimento per ottimizzare le risorse
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  // Configurazione dei browser da usare
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        // Opzioni necessarie per eseguire Chrome in ambienti containerizzati/CI
        launchOptions: {
          args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
        },
      },
    },
  ],

  // Directory per gli output dei test (es. screenshot, video)
  outputDir: 'playwright-artifacts/',
});
