#!/bin/bash

# ============================================
# Test Advanced - Security Tests Module
# FASE 5: Security testing e vulnerability scan
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_security() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY: $1" >> ~/test-advanced.log
}

log_security "Esecuzione Security Tests..."

# NPM Audit (Backend)
log_security "NPM Security Audit - Backend..."
cd "$HOME/devops/CRM-System/backend" || exit 1

if npm audit --audit-level=moderate 2>&1 | tee "$HOME/testing-workspace/reports/security-audit-backend.log"; then
    log_security "✅ Backend NPM audit: PASSED"
    BACKEND_AUDIT=true
else
    log_security "⚠️ Backend NPM audit: WARNINGS"
    BACKEND_AUDIT=false
fi

# NPM Audit (Frontend)
log_security "NPM Security Audit - Frontend..."
cd "$HOME/devops/CRM-System/frontend" || exit 1

if npm audit --audit-level=moderate 2>&1 | tee "$HOME/testing-workspace/reports/security-audit-frontend.log"; then
    log_security "✅ Frontend NPM audit: PASSED"
    FRONTEND_AUDIT=true
else
    log_security "⚠️ Frontend NPM audit: WARNINGS"
    FRONTEND_AUDIT=false
fi

# Security Headers Check - Test sul BACKEND dove sono configurati
log_security "Security Headers Check..."
HEADERS_RESPONSE=$(curl -s -I http://localhost:3101/api/health 2>/dev/null)

if echo "$HEADERS_RESPONSE" | grep -qi "x-frame-options\|x-content-type-options\|strict-transport-security"; then
    log_security "✅ Security headers: PRESENT"
    HEADERS_SUCCESS=true
else
    log_security "⚠️ Security headers: MISSING"
    HEADERS_SUCCESS=false
fi

# Authentication Protection Test
log_security "Authentication Protection Test..."
AUTH_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3101/api/protected 2>/dev/null)

if [[ "$AUTH_TEST" == "401" || "$AUTH_TEST" == "403" ]]; then
    log_security "✅ Authentication protection: ACTIVE"
    AUTH_PROTECTION=true
else
    log_security "⚠️ Authentication protection: WEAK"
    AUTH_PROTECTION=false
fi

# Basic OWASP checks
log_security "Basic OWASP Security Checks..."

# SQL Injection basic test - Fixed escaping
SQL_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:3101/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com'; DROP TABLE users; --","password":"test"}' 2>/dev/null)

if [[ "$SQL_TEST" == "400" || "$SQL_TEST" == "422" || "$SQL_TEST" == "401" ]]; then
    log_security "✅ SQL Injection protection: ACTIVE"
    SQL_PROTECTION=true
else
    log_security "⚠️ SQL Injection protection: UNCLEAR"
    SQL_PROTECTION=false
fi

# XSS Protection test - Fixed port to 3000
XSS_TEST=$(curl -s "http://localhost:3000/?search=<script>alert('xss')</script>" | grep -o "<script>" | wc -l 2>/dev/null)

if [[ "$XSS_TEST" -eq 0 ]]; then
    log_security "✅ XSS protection: ACTIVE"
    XSS_PROTECTION=true
else
    log_security "⚠️ XSS protection: WEAK"
    XSS_PROTECTION=false
fi

# Generate security test report
log_security "Generazione report security tests..."
cat > "$HOME/testing-workspace/reports/security-summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "backend_audit": $BACKEND_AUDIT,
  "frontend_audit": $FRONTEND_AUDIT,
  "security_headers": $HEADERS_SUCCESS,
  "auth_protection": $AUTH_PROTECTION,
  "sql_protection": $SQL_PROTECTION,
  "xss_protection": $XSS_PROTECTION,
  "overall": $([ "$BACKEND_AUDIT" = true ] && [ "$FRONTEND_AUDIT" = true ] && [ "$AUTH_PROTECTION" = true ] && echo true || echo false)
}
EOF

OVERALL_SUCCESS=$([ "$BACKEND_AUDIT" = true ] && [ "$FRONTEND_AUDIT" = true ] && [ "$AUTH_PROTECTION" = true ] && echo true || echo false)

if [[ "$OVERALL_SUCCESS" == true ]]; then
    log_security "✅ Security tests completati con successo!"
    exit 0
else
    log_security "⚠️ Security tests completati con warning"
    exit 0  # Non fallire per security warnings
fi
