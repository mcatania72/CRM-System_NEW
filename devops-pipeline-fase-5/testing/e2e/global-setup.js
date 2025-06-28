// Global Setup per Playwright E2E Tests
// FASE 5: Enterprise Testing Strategy

const { chromium } = require('@playwright/test');

async function globalSetup() {
  console.log('🔧 Global setup: Auto-detecting services...');
  
  // Auto-detect delle porte attive
  const ports = {
    frontend: await detectServicePort([3100, 3000, 4173, 3002], 'frontend'),
    backend: await detectServicePort([3101, 3001, 8000, 8001], 'backend')
  };
  
  console.log(`✅ Services detected:`);
  console.log(`   Frontend: http://localhost:${ports.frontend}`);
  console.log(`   Backend: http://localhost:${ports.backend}`);
  
  // Set environment variables per i test
  process.env.FRONTEND_PORT = ports.frontend.toString();
  process.env.BACKEND_PORT = ports.backend.toString();
  process.env.FRONTEND_URL = `http://localhost:${ports.frontend}`;
  process.env.BACKEND_URL = `http://localhost:${ports.backend}`;
  
  // Verifica di base che i servizi rispondano
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  try {
    await page.goto(`http://localhost:${ports.frontend}`, { timeout: 10000 });
    console.log('✅ Frontend accessible');
  } catch (error) {
    console.log('⚠️ Frontend check warning:', error.message);
  }
  
  try {
    const response = await page.request.get(`http://localhost:${ports.backend}/api/health`);
    if (response.ok()) {
      console.log('✅ Backend API accessible');
    } else {
      console.log('⚠️ Backend API warning: status', response.status());
    }
  } catch (error) {
    console.log('⚠️ Backend API check warning:', error.message);
  }
  
  await browser.close();
  
  console.log('🎯 Global setup completed\n');
}

async function detectServicePort(ports, serviceName) {
  const http = require('http');
  
  for (const port of ports) {
    try {
      const isActive = await new Promise((resolve) => {
        const req = http.request({
          hostname: 'localhost',
          port: port,
          timeout: 2000,
          method: 'HEAD'
        }, (res) => {
          resolve(true);
        });
        
        req.on('error', () => resolve(false));
        req.on('timeout', () => resolve(false));
        req.end();
      });
      
      if (isActive) {
        console.log(`🔍 ${serviceName} found on port ${port}`);
        return port;
      }
    } catch (error) {
      continue;
    }
  }
  
  console.log(`⚠️ ${serviceName} not found on any port, using default: ${ports[0]}`);
  return ports[0]; // Fallback al primo porto
}

module.exports = globalSetup;