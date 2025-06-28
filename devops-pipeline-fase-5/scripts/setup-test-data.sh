#!/bin/bash

# ============================================
# Setup Test Data Script
# FASE 5: Inizializzazione dati di test
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_test_data() {
    echo -e "${BLUE}[TEST-DATA]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') TEST-DATA: $1" >> ~/deploy-testing.log
}

log_test_data "Setup test data per testing environment..."

# Wait for backend to be ready
log_test_data "Attesa backend ready..."
for i in {1..30}; do
    if curl -s http://localhost:3101/api/health >/dev/null 2>&1; then
        log_test_data "✅ Backend pronto"
        break
    fi
    sleep 1
    if [[ $i -eq 30 ]]; then
        log_test_data "❌ Backend non disponibile dopo 30s"
        exit 1
    fi
done

# Create admin user for testing
log_test_data "Creazione admin user per test..."
ADMIN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@crm.local",
        "password": "admin123",
        "firstName": "Admin",
        "lastName": "User",
        "role": "admin"
    }' \
    http://localhost:3101/api/auth/register 2>/dev/null)

if echo "$ADMIN_RESPONSE" | grep -q "success\|user\|id"; then
    log_test_data "✅ Admin user creato"
else
    log_test_data "ℹ️ Admin user già esistente o creazione fallita"
fi

log_test_data "✅ Admin user ready"

# Get auth token for further operations
log_test_data "Ottenimento auth token..."
TOKEN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@crm.local",
        "password": "admin123"
    }' \
    http://localhost:3101/api/auth/login 2>/dev/null)

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
    log_test_data "✅ Auth token ottenuto"
else
    log_test_data "❌ Auth token non ottenuto"
    exit 1
fi

# Create test customers
log_test_data "Creazione test customers..."
TEST_CUSTOMERS=(
    '{"name":"Test Customer 1","email":"customer1@test.com","phone":"+1234567890","company":"Test Corp","address":"123 Test St","city":"Test City","country":"Test Country"}'
    '{"name":"Test Customer 2","email":"customer2@test.com","phone":"+1234567891","company":"Demo Inc","address":"456 Demo Ave","city":"Demo City","country":"Demo Country"}'
    '{"name":"Test Customer 3","email":"customer3@test.com","phone":"+1234567892","company":"Sample LLC","address":"789 Sample Blvd","city":"Sample City","country":"Sample Country"}'
)

for customer_data in "${TEST_CUSTOMERS[@]}"; do
    CUSTOMER_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$customer_data" \
        http://localhost:3101/api/customers 2>/dev/null)
    
    if echo "$CUSTOMER_RESPONSE" | grep -q "id\|success"; then
        log_test_data "✅ Test customer creato"
    else
        log_test_data "⚠️ Test customer già esistente o errore"
    fi
done

# Create test opportunities
log_test_data "Creazione test opportunities..."
TEST_OPPORTUNITIES=(
    '{"title":"Test Opportunity 1","description":"First test opportunity","value":10000,"stage":"prospect","probability":25,"customerId":1}'
    '{"title":"Test Opportunity 2","description":"Second test opportunity","value":25000,"stage":"qualified","probability":50,"customerId":2}'
    '{"title":"Test Opportunity 3","description":"Third test opportunity","value":15000,"stage":"proposal","probability":75,"customerId":3}'
)

for opportunity_data in "${TEST_OPPORTUNITIES[@]}"; do
    OPPORTUNITY_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$opportunity_data" \
        http://localhost:3101/api/opportunities 2>/dev/null)
    
    if echo "$OPPORTUNITY_RESPONSE" | grep -q "id\|success"; then
        log_test_data "✅ Test opportunity creato"
    else
        log_test_data "⚠️ Test opportunity già esistente o errore"
    fi
done

# Save test credentials for later use
cat > "$HOME/testing-workspace/.test-credentials" << EOF
# Test Credentials for CRM System
ADMIN_EMAIL=admin@crm.local
ADMIN_PASSWORD=admin123
AUTH_TOKEN=$TOKEN
BACKEND_URL=http://localhost:3101
FRONTEND_URL=http://localhost:3100
EOF

log_test_data "✅ Setup test data completato"
log_test_data "📝 Credenziali salvate in: ~/testing-workspace/.test-credentials"

exit 0