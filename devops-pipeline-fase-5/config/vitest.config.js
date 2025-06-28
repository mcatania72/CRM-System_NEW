// Vitest Configuration for Frontend Testing
// FASE 5: Enterprise Testing Strategy

import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  
  test: {
    // Test environment
    environment: 'jsdom',
    
    // Setup files
    setupFiles: ['../testing/config/vitest.setup.js'],
    
    // Global test configuration
    globals: true,
    
    // Coverage configuration
    coverage: {
      provider: 'c8',
      reporter: ['text', 'json', 'html'],
      reportsDirectory: '../testing-workspace/coverage/frontend',
      threshold: {
        global: {
          branches: 70,
          functions: 70,
          lines: 70,
          statements: 70
        }
      },
      include: [
        'src/**/*.{js,jsx,ts,tsx}'
      ],
      exclude: [
        'src/main.jsx',
        'src/index.js',
        '**/*.config.js',
        '**/node_modules/**'
      ]
    },
    
    // Test timeout
    testTimeout: 30000,
    
    // Include patterns
    include: [
      'src/**/*.{test,spec}.{js,jsx,ts,tsx}',
      'testing/unit/frontend/**/*.{test,spec}.{js,jsx}'
    ],
    
    // Exclude patterns
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/cypress/**'
    ]
  },
  
  // Resolve configuration
  resolve: {
    alias: {
      '@': '/src'
    }
  }
});