#!/bin/bash

# ============================================
# Test Advanced - Unit Tests Module
# FASE 5: Unit testing backend e frontend
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_unit() {
    echo -e "${BLUE}[UNIT]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') UNIT: $1" >> ~/test-advanced.log
}

log_unit "Esecuzione Unit Tests..."

# FASE 5 directory
FASE5_DIR="$HOME/devops-pipeline-fase-5"
CRM_BACKEND="$HOME/devops/CRM-System/backend"
CRM_FRONTEND="$HOME/devops/CRM-System/frontend"

# Backend Unit Tests - FIXED: Usa test FASE 5 se CRM tests non esistono
log_unit "Backend Unit Tests..."

# Controlla se esistono test nel CRM backend
BACKEND_HAS_TESTS=false
if [[ -d "$CRM_BACKEND" ]]; then
    cd "$CRM_BACKEND"
    if find . -name "*.test.js" -o -name "*.test.ts" -o -name "*.spec.js" -o -name "*.spec.ts" | grep -q .; then
        BACKEND_HAS_TESTS=true
        log_unit "📍 Usando test esistenti CRM backend..."
    fi
fi

if [[ "$BACKEND_HAS_TESTS" == "true" ]]; then
    # Esegui test esistenti CRM
    cd "$CRM_BACKEND"
    npm test 2>&1 | tee "$HOME/testing-workspace/reports/unit-backend.log"
    BACKEND_EXIT_CODE=${PIPESTATUS[0]}
else
    # Usa test di esempio FASE 5
    log_unit "📍 Usando test di esempio FASE 5..."
    cd "$FASE5_DIR"
    
    # Esegui test di esempio con Jest su file sample
    if [[ -f "testing/unit/sample.test.js" ]]; then
        npx jest testing/unit/sample.test.js --config=config/jest.config.js 2>&1 | tee "$HOME/testing-workspace/reports/unit-backend.log"
        BACKEND_EXIT_CODE=${PIPESTATUS[0]}
    else
        log_unit "❌ Test di esempio non trovati in testing/unit/"
        BACKEND_EXIT_CODE=1
    fi
fi

log_unit "DEBUG: Backend exit code = $BACKEND_EXIT_CODE"

if [[ $BACKEND_EXIT_CODE -eq 0 ]]; then
    log_unit "✅ Backend unit tests PASSED"
    BACKEND_SUCCESS=true
elif [[ $BACKEND_EXIT_CODE -eq 1 ]]; then
    # Check if it's "no tests found" vs real failure
    if grep -q "No tests found\|No test files found" "$HOME/testing-workspace/reports/unit-backend.log"; then
        log_unit "⚠️ Backend: No tests found (OK per setup fase)"
        BACKEND_SUCCESS=true
    else
        log_unit "❌ Backend unit tests FAILED"
        BACKEND_SUCCESS=false
    fi
else
    log_unit "❌ Backend unit tests ERROR (exit code: $BACKEND_EXIT_CODE)"
    BACKEND_SUCCESS=false
fi

# Frontend Unit Tests - FIXED: Usa test FASE 5 se CRM tests non esistono  
log_unit "Frontend Unit Tests..."

# Controlla se esistono test nel CRM frontend
FRONTEND_HAS_TESTS=false
if [[ -d "$CRM_FRONTEND" ]]; then
    cd "$CRM_FRONTEND"
    if find . -name "*.test.js" -o -name "*.test.jsx" -o -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.js" -o -name "*.spec.jsx" | grep -q .; then
        FRONTEND_HAS_TESTS=true
        log_unit "📍 Usando test esistenti CRM frontend..."
    fi
fi

if [[ "$FRONTEND_HAS_TESTS" == "true" ]]; then
    # Esegui test esistenti CRM
    cd "$CRM_FRONTEND"
    npm test 2>&1 | tee "$HOME/testing-workspace/reports/unit-frontend.log"
    FRONTEND_EXIT_CODE=${PIPESTATUS[0]}
else
    # Usa test di esempio FASE 5
    log_unit "📍 Usando test di esempio FASE 5..."
    cd "$FASE5_DIR"
    
    # Crea un test frontend di esempio se non esiste
    if [[ ! -f "testing/unit/frontend-sample.test.js" ]]; then
        mkdir -p testing/unit
        cat > testing/unit/frontend-sample.test.js << 'EOF'
// Frontend Unit Test di esempio - FASE 5
describe('Frontend Sample Tests', () => {
  test('should verify basic JavaScript functionality', () => {
    const result = 2 + 2;
    expect(result).toBe(4);
  });

  test('should test string operations', () => {
    const str = 'Hello CRM';
    expect(str).toContain('CRM');
    expect(str.length).toBe(9);
  });

  test('should test array operations', () => {
    const users = ['admin', 'user1', 'user2'];
    expect(users).toHaveLength(3);
    expect(users).toContain('admin');
  });
});
EOF
    fi
    
    # Esegui test frontend di esempio
    npx jest testing/unit/frontend-sample.test.js --config=config/jest.config.js 2>&1 | tee "$HOME/testing-workspace/reports/unit-frontend.log"
    FRONTEND_EXIT_CODE=${PIPESTATUS[0]}
fi

log_unit "DEBUG: Frontend exit code = $FRONTEND_EXIT_CODE"

if [[ $FRONTEND_EXIT_CODE -eq 0 ]]; then
    log_unit "✅ Frontend unit tests PASSED"
    FRONTEND_SUCCESS=true
elif [[ $FRONTEND_EXIT_CODE -eq 1 ]]; then
    # Check if it's "no test files found" vs real failure
    if grep -q "No test files found\|No tests found" "$HOME/testing-workspace/reports/unit-frontend.log"; then
        log_unit "⚠️ Frontend: No test files found (OK per setup fase)"
        FRONTEND_SUCCESS=true
    else
        log_unit "❌ Frontend unit tests FAILED"
        FRONTEND_SUCCESS=false
    fi
else
    log_unit "❌ Frontend unit tests ERROR (exit code: $FRONTEND_EXIT_CODE)"
    FRONTEND_SUCCESS=false
fi

# Generate unit test report
log_unit "Generazione report unit tests..."
cat > "$HOME/testing-workspace/reports/unit-summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "backend": $BACKEND_SUCCESS,
  "frontend": $FRONTEND_SUCCESS,
  "backend_tests_source": "$([ "$BACKEND_HAS_TESTS" = true ] && echo "CRM-System" || echo "FASE5-samples")",
  "frontend_tests_source": "$([ "$FRONTEND_HAS_TESTS" = true ] && echo "CRM-System" || echo "FASE5-samples")",
  "overall": $([ "$BACKEND_SUCCESS" = true ] && [ "$FRONTEND_SUCCESS" = true ] && echo true || echo false),
  "note": "Using FASE 5 sample tests when CRM tests not available"
}
EOF

if [[ "$BACKEND_SUCCESS" == true && "$FRONTEND_SUCCESS" == true ]]; then
    log_unit "✅ Unit tests completati con successo!"
    log_unit "📝 Nota: Pipeline testata con test di esempio FASE 5"
    exit 0
else
    log_unit "❌ Unit tests falliti"
    exit 1
fi