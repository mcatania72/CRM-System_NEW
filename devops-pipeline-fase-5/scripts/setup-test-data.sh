#!/bin/bash

# =======================================
#   Setup Test Data
#   FASE 5: Test Data Management
# =======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[TEST-DATA]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST-DATA]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[TEST-DATA]${NC} ❌ $1"
}

# Configuration
TEST_PORT_BACKEND=3101
TEST_DATA_DIR="$HOME/devops/CRM-System/testing/data"

log_info "Setup test data per testing environment..."

# Create test data directory
mkdir -p "$TEST_DATA_DIR"

# Wait for backend to be ready
log_info "Attesa backend ready..."
for i in {1..30}; do
    if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" >/dev/null; then
        log_success "Backend ready"
        break
    fi
    sleep 2
done

# Create test admin user
log_info "Creazione admin user per test..."
ADMIN_RESPONSE=$(curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Test Admin",
        "email": "admin@crm.local",
        "password": "admin123",
        "role": "admin"
    }' 2>/dev/null || echo '{"error":"user exists"}')

if echo "$ADMIN_RESPONSE" | grep -q "token\|exists"; then
    log_success "Admin user ready"
else
    log_error "Admin user creation failed"
fi

# Get auth token
log_info "Ottenimento auth token..."
TOKEN=$(curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@crm.local","password":"admin123"}' | \
    node -e "try { const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8')); console.log(data.token || ''); } catch(e) { console.log(''); }" 2>/dev/null)

if [ -n "$TOKEN" ]; then
    log_success "Auth token ottenuto"
else
    log_error "Auth token non ottenuto"
    exit 1
fi

# Create test customers
log_info "Creazione test customers..."
for i in {1..10}; do
    curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/customers" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"Test Customer $i\",
            \"email\": \"customer$i@example.com\",
            \"phone\": \"+123456789$i\",
            \"company\": \"Test Company $i\"
        }" >/dev/null
done

log_success "10 test customers creati"

# Create test opportunities
log_info "Creazione test opportunities..."
for i in {1..5}; do
    curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/opportunities" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Test Opportunity $i\",
            \"description\": \"Test opportunity description $i\",
            \"value\": $((i * 1000)),
            \"stage\": \"prospect\",
            \"customer_id\": $i
        }" >/dev/null
done

log_success "5 test opportunities create"

# Save test data info
cat > "$TEST_DATA_DIR/test-data-info.json" << EOF
{
    "created_at": "$(date -Iseconds)",
    "admin_user": {
        "email": "admin@crm.local",
        "password": "admin123"
    },
    "test_customers": 10,
    "test_opportunities": 5,
    "backend_url": "http://localhost:$TEST_PORT_BACKEND",
    "frontend_url": "http://localhost:3100"
}
EOF

log_success "Test data setup completato!"
log_info "Info salvate in: $TEST_DATA_DIR/test-data-info.json"