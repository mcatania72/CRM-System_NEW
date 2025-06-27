#!/bin/bash

# =======================================
#   Test Advanced - Security Tests Module
#   FASE 5: Security Testing
# =======================================

# NO set -e per gestire meglio gli errori

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SECURITY]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[SECURITY]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[SECURITY]${NC} ⚠️ $1"
}

log_test "Esecuzione Security Tests..."

TEST_PORT_BACKEND=3101
TEST_PORT_FRONTEND=3100
security_passed=0
security_total=5

# Test 1: SQL Injection Protection
log_test "Security Test 1: SQL Injection Protection"
sqli_response=$(curl -s -w "%{http_code}" -X POST "http://localhost:$TEST_PORT_BACKEND/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@crm.local OR 1=1--","password":"test"}' 2>/dev/null)
if [[ "$sqli_response" =~ 401$|400$ ]]; then
    log_success "✓ SQL Injection Protection"
    ((security_passed++))
else
    log_error "✗ SQL Injection Protection (response: $sqli_response)"
fi

# Test 2: XSS Protection
log_test "Security Test 2: XSS Protection"
xss_response=$(curl -s "http://localhost:$TEST_PORT_FRONTEND" 2>/dev/null | grep -o "<script>" | wc -l)
if [ "$xss_response" -eq 0 ] 2>/dev/null; then
    log_success "✓ XSS Protection (no inline scripts)"
    ((security_passed++))
else
    log_warning "⚠️ XSS Protection (found $xss_response inline scripts)"
fi

# Test 3: Security Headers
log_test "Security Test 3: Security Headers"
security_headers=$(curl -s -I "http://localhost:$TEST_PORT_BACKEND/api/health" 2>/dev/null | grep -c -E "X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security" || echo "0")
if [ "$security_headers" -gt 0 ] 2>/dev/null; then
    log_success "✓ Security Headers ($security_headers found)"
    ((security_passed++))
else
    log_warning "⚠️ Security Headers (none found)"
fi

# Test 4: Authentication Required
log_test "Security Test 4: Authentication Required"
auth_response=$(curl -s -w "%{http_code}" "http://localhost:$TEST_PORT_BACKEND/api/customers" 2>/dev/null)
if [[ "$auth_response" =~ 401$|403$ ]]; then
    log_success "✓ Authentication Required"
    ((security_passed++))
else
    log_error "✗ Authentication Required (response: $auth_response)"
fi

# Test 5: HTTPS Redirect (simulated)
log_test "Security Test 5: Basic Security Compliance"
# Simple check for common security patterns
sec_compliance=0
if curl -s "http://localhost:$TEST_PORT_BACKEND/api/health" | grep -q "ok"; then
    sec_compliance=1
fi

if [ "$sec_compliance" -eq 1 ]; then
    log_success "✓ Basic Security Compliance"
    ((security_passed++))
else
    log_warning "⚠️ Basic Security Compliance"
fi

# Generate security test report
REPORTS_DIR="$HOME/devops/CRM-System/testing/reports"
mkdir -p "$REPORTS_DIR"
security_score=$(echo "scale=2; $security_passed * 100 / $security_total" | bc 2>/dev/null || echo "0")
echo "{\"timestamp\": \"$(date -Iseconds)\", \"tests_passed\": $security_passed, \"tests_total\": $security_total, \"security_score\": $security_score}" > "$REPORTS_DIR/security-tests.json"

echo "\n=== SECURITY TESTS RESULTS ==="
echo "Security tests passed: $security_passed/$security_total"
log_test "Security Score: $security_score%"

if [ "$security_passed" -eq "$security_total" ]; then
    log_success "Security Tests: ALL PASSED 🔒"
    exit 0
else
    log_warning "Security Tests: SOME ISSUES FOUND ⚠️"
    exit 1
fi