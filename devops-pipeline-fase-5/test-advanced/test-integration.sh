#!/bin/bash

# ============================================
# Test Advanced - Integration Tests Module
# FASE 5: Integration testing API e database
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_integration() {
    echo -e "${BLUE}[INTEGRATION]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INTEGRATION: $1" >> ~/test-advanced.log
}

log_integration "Esecuzione Integration Tests..."

# Test API Endpoints
log_integration "Test API Endpoints..."

# Health check
if curl -s --max-time 10 http://localhost:3101/api/health | grep -q "OK"; then
    log_integration "✅ API Health endpoint OK"
    API_HEALTH=true
else
    log_integration "❌ API Health endpoint FAILED"
    API_HEALTH=false
fi

# Auth endpoints
log_integration "Test Auth API..."
AUTH_RESPONSE=$(curl -s --max-time 10 -X POST \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@crm.local","password":"admin123"}' \
    http://localhost:3101/api/auth/login)

if echo "$AUTH_RESPONSE" | grep -q "token\|success"; then
    log_integration "✅ Auth API login OK"
    AUTH_SUCCESS=true
else
    log_integration "❌ Auth API login FAILED"
    AUTH_SUCCESS=false
fi

# Database connectivity
log_integration "Test Database Connectivity..."
if [[ -f "$HOME/testing-workspace/test.db" ]]; then
    if sqlite3 "$HOME/testing-workspace/test.db" "SELECT COUNT(*) FROM users;" >/dev/null 2>&1; then
        log_integration "✅ Database connectivity OK"
        DB_SUCCESS=true
    else
        log_integration "❌ Database query FAILED"
        DB_SUCCESS=false
    fi
else
    log_integration "❌ Test database not found"
    DB_SUCCESS=false
fi

# Frontend-Backend integration
log_integration "Test Frontend-Backend Integration..."
if curl -s --max-time 10 http://localhost:3100 | grep -q "CRM\|Dashboard\|Login"; then
    log_integration "✅ Frontend-Backend integration OK"
    FE_BE_SUCCESS=true
else
    log_integration "❌ Frontend-Backend integration FAILED"
    FE_BE_SUCCESS=false
fi

# Generate integration test report
log_integration "Generazione report integration tests..."
cat > "$HOME/testing-workspace/reports/integration-summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "api_health": $API_HEALTH,
  "auth_api": $AUTH_SUCCESS,
  "database": $DB_SUCCESS,
  "frontend_backend": $FE_BE_SUCCESS,
  "overall": $([ "$API_HEALTH" = true ] && [ "$AUTH_SUCCESS" = true ] && [ "$DB_SUCCESS" = true ] && [ "$FE_BE_SUCCESS" = true ] && echo true || echo false)
}
EOF

if [[ "$API_HEALTH" == true && "$AUTH_SUCCESS" == true && "$DB_SUCCESS" == true && "$FE_BE_SUCCESS" == true ]]; then
    log_integration "✅ Integration tests completati con successo!"
    exit 0
else
    log_integration "❌ Integration tests falliti"
    exit 1
fi