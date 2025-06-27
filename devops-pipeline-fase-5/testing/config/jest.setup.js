// Jest Setup Configuration
// FASE 5: Enterprise Testing Strategy

// Setup testing environment
process.env.NODE_ENV = 'test';
process.env.TEST_MODE = 'true';

// Mock console methods in test environment
if (process.env.NODE_ENV === 'test') {
  global.console = {
    ...console,
    // Uncomment to suppress console output during tests
    // log: jest.fn(),
    // warn: jest.fn(),
    // error: jest.fn(),
  };
}

// Global test utilities
global.testUtils = {
  // Mock user for testing
  mockUser: {
    id: 1,
    email: 'test@example.com',
    name: 'Test User',
    role: 'user'
  },
  
  // Mock customer data
  mockCustomer: {
    id: 1,
    name: 'Test Customer',
    email: 'customer@example.com',
    phone: '+1234567890',
    company: 'Test Company'
  }
};

// Setup and teardown
beforeEach(() => {
  // Reset mocks before each test
  jest.clearAllMocks();
});

afterEach(() => {
  // Cleanup after each test
  jest.restoreAllMocks();
});