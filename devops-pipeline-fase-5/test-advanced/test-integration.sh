#!/bin/bash

# =======================================
#   Test Advanced - Integration Tests Module
#   FASE 5: Integration Testing
# =======================================

# NO set -e per gestire meglio gli errori

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    echo -e "${BLUE}[INTEGRATION]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[INTEGRATION]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[INTEGRATION]${NC} ❌ $1"
}

log_test "Esecuzione Integration Tests..."

TEST_PORT_BACKEND=3101
tests_passed=0
tests_total=6

# Test 1: API Health Check
log_test "Test 1: API Health Check"
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" | grep -q "ok"; then
    log_success "✓ API Health Check"
    ((tests_passed++))
else
    log_error "✗ API Health Check"
fi

# Test 2: Authentication Flow
log_test "Test 2: Authentication Flow"
token=$(curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@crm.local","password":"admin123"}' | \
    node -e "try { const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8')); console.log(data.token || ''); } catch(e) { console.log(''); }" 2>/dev/null)

if [ -n "$token" ]; then
    log_success "✓ Authentication Flow"
    ((tests_passed++))
else
    log_error "✗ Authentication Flow"
fi

# Test 3: Database Connection
log_test "Test 3: Database Connection"
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/customers" \
    -H "Authorization: Bearer $token" | grep -q "\[\|{\|customers"; then
    log_success "✓ Database Connection"
    ((tests_passed++))
else
    log_error "✗ Database Connection"
fi

# Test 4: CRUD Operations
log_test "Test 4: CRUD Operations"
customer_id=$(curl -s -X POST "http://localhost:$TEST_PORT_BACKEND/api/customers" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"name":"Integration Test Customer","email":"integration@test.com","phone":"+1234567890"}' | \
    node -e "try { const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8')); console.log(data.id || ''); } catch(e) { console.log(''); }" 2>/dev/null)

if [ -n "$customer_id" ]; then
    log_success "✓ CRUD Operations (Customer created: $customer_id)"
    ((tests_passed++))
else
    log_error "✗ CRUD Operations"
fi

# Test 5: API Error Handling
log_test "Test 5: API Error Handling"
error_response=$(curl -s -w "%{http_code}" "http://localhost:$TEST_PORT_BACKEND/api/nonexistent")
if [[ "$error_response" =~ 404$ ]]; then
    log_success "✓ API Error Handling (404 for nonexistent endpoint)"
    ((tests_passed++))
else
    log_error "✗ API Error Handling (expected 404, got: $error_response)"
fi

# Test 6: Data Validation
log_test "Test 6: Data Validation"
validation_response=$(curl -s -w "%{http_code}" -X POST "http://localhost:$TEST_PORT_BACKEND/api/customers" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"invalid":"data"}')
if [[ "$validation_response" =~ 400$ ]]; then
    log_success "✓ Data Validation (400 for invalid data)"
    ((tests_passed++))
else
    log_error "✗ Data Validation (expected 400, got: $validation_response)"
fi

REPORTS_DIR="$HOME/devops/CRM-System/testing/reports"
mkdir -p "$REPORTS_DIR"
echo "{\"timestamp\": \"$(date -Iseconds)\", \"tests_passed\": $tests_passed, \"tests_total\": $tests_total, \"success_rate\": $(echo "scale=2; $tests_passed * 100 / $tests_total" | bc 2>/dev/null || echo "0")}" > "$REPORTS_DIR/integration-tests.json"

echo "\n=== INTEGRATION TESTS RESULTS ==="
echo "Tests passed: $tests_passed/$tests_total"

success_rate=$(echo "scale=2; $tests_passed * 100 / $tests_total" | bc 2>/dev/null || echo "0")
if [ "$tests_passed" -eq "$tests_total" ]; then
    log_success "Integration Tests: $success_rate%"
    exit 0
else
    log_error "Integration Tests: $success_rate%"
    exit 1
fi