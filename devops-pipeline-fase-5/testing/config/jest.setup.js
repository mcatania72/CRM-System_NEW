// Jest Setup Configuration
// FASE 5: Enterprise Testing Strategy

// Import testing utilities
const path = require('path');
const fs = require('fs');

// Setup test environment variables
process.env.NODE_ENV = 'test';
process.env.TEST_MODE = 'true';
process.env.DB_PATH = path.join(process.env.HOME, 'testing-workspace', 'test.db');
process.env.PORT = '3101';
process.env.JWT_SECRET = 'test-secret-key-for-testing-only';

// Global test timeout
jest.setTimeout(30000);

// Setup global test helpers
global.testHelpers = {
  // Create test user
  createTestUser: () => ({
    id: 1,
    email: 'test@example.com',
    password: 'hashedpassword',
    firstName: 'Test',
    lastName: 'User',
    role: 'user',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }),
  
  // Create test customer
  createTestCustomer: () => ({
    id: 1,
    name: 'Test Customer',
    email: 'customer@example.com',
    phone: '+1234567890',
    company: 'Test Company',
    address: '123 Test Street',
    city: 'Test City',
    country: 'Test Country',
    status: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }),
  
  // Create test opportunity
  createTestOpportunity: () => ({
    id: 1,
    title: 'Test Opportunity',
    description: 'Test opportunity description',
    value: 10000,
    stage: 'prospect',
    probability: 25,
    customerId: 1,
    assignedTo: 1,
    expectedCloseDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }),
  
  // Generate JWT token for testing
  generateTestToken: (payload = { id: 1, email: 'test@example.com' }) => {
    const jwt = require('jsonwebtoken');
    return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '1h' });
  },
  
  // Clean test database
  cleanTestDatabase: async () => {
    const dbPath = process.env.DB_PATH;
    if (fs.existsSync(dbPath)) {
      try {
        fs.unlinkSync(dbPath);
        console.log('Test database cleaned');
      } catch (error) {
        console.warn('Could not clean test database:', error.message);
      }
    }
  }
};

// Setup and teardown hooks
beforeAll(async () => {
  // Ensure test workspace exists
  const testWorkspace = path.join(process.env.HOME, 'testing-workspace');
  if (!fs.existsSync(testWorkspace)) {
    fs.mkdirSync(testWorkspace, { recursive: true });
  }
  
  // Clean any existing test database
  await global.testHelpers.cleanTestDatabase();
});

afterAll(async () => {
  // Clean up after all tests
  await global.testHelpers.cleanTestDatabase();
});

// Mock console methods to reduce test noise
const originalConsole = { ...console };
beforeEach(() => {
  // Optionally suppress console.log in tests
  if (process.env.SUPPRESS_TEST_LOGS === 'true') {
    console.log = jest.fn();
    console.info = jest.fn();
  }
});

afterEach(() => {
  // Restore console
  if (process.env.SUPPRESS_TEST_LOGS === 'true') {
    console.log = originalConsole.log;
    console.info = originalConsole.info;
  }
  
  // Clear all mocks
  jest.clearAllMocks();
});

// Export test utilities
module.exports = {
  testHelpers: global.testHelpers
};