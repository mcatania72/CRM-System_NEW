#!/bin/bash

# =======================================
#   Test Advanced - Performance Tests Module
#   FASE 5: Performance Testing
# =======================================

# NO set -e per gestire meglio gli errori

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_perf() {
    echo -e "${CYAN}[PERF]${NC} ⚡ $1"
}

log_success() {
    echo -e "${GREEN}[PERF]${NC} ✅ $1"
}

log_error() {
    echo -e "${RED}[PERF]${NC} ❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[PERF]${NC} ⚠️ $1"
}

log_perf "Esecuzione Performance Tests..."

# Check if Artillery is installed
if ! command -v artillery >/dev/null 2>&1; then
    log_error "Artillery non installato"
    exit 1
fi

TEST_PORT_BACKEND=3101
REPORTS_DIR="$HOME/devops/CRM-System/testing/reports"
ARTIFACTS_DIR="$HOME/devops/CRM-System/testing/artifacts"
mkdir -p "$REPORTS_DIR" "$ARTIFACTS_DIR"

# Create Artillery config if not exists
artillery_config="$ARTIFACTS_DIR/performance-test.yml"
if [ ! -f "$artillery_config" ]; then
    cp "$HOME/devops-pipeline-fase-5/config/artillery.config.yml" "$artillery_config"
fi

# Run Artillery performance test
log_perf "Avvio performance test con Artillery..."
if artillery run "$artillery_config" --output "$REPORTS_DIR/performance-results.json" > "$REPORTS_DIR/performance-tests.log" 2>&1; then
    log_success "Performance test completato"
else
    log_error "Performance test fallito"
    exit 1
fi

# Generate HTML report if results exist
if [ -f "$REPORTS_DIR/performance-results.json" ]; then
    if artillery report "$REPORTS_DIR/performance-results.json" --output "$REPORTS_DIR/performance-report.html" 2>/dev/null; then
        log_success "Report HTML generato"
    else
        log_warning "Report HTML non generato"
    fi
    
    # Extract key metrics with fallback
    avg_response_time=$(node -e "
        try {
            const data = JSON.parse(require('fs').readFileSync('$REPORTS_DIR/performance-results.json', 'utf8'));
            const aggregate = data.aggregate;
            console.log(Math.round(aggregate.latency?.mean || 0));
        } catch(e) {
            console.log('0');
        }
    " 2>/dev/null || echo "0")
    
    requests_per_sec=$(node -e "
        try {
            const data = JSON.parse(require('fs').readFileSync('$REPORTS_DIR/performance-results.json', 'utf8'));
            const aggregate = data.aggregate;
            console.log(Math.round(aggregate.rps?.mean || 0));
        } catch(e) {
            console.log('0');
        }
    " 2>/dev/null || echo "0")
    
    log_perf "Average Response Time: ${avg_response_time}ms"
    log_perf "Requests per Second: ${requests_per_sec}"
    
    # Simple threshold checks
    PERFORMANCE_RESPONSE_THRESHOLD=2000
    PERFORMANCE_THROUGHPUT_THRESHOLD=10
    
    perf_passed=true
    if [ "$avg_response_time" -gt "$PERFORMANCE_RESPONSE_THRESHOLD" ] 2>/dev/null; then
        log_warning "Response time above threshold: ${avg_response_time}ms > ${PERFORMANCE_RESPONSE_THRESHOLD}ms"
        perf_passed=false
    fi
    
    if [ "$requests_per_sec" -lt "$PERFORMANCE_THROUGHPUT_THRESHOLD" ] 2>/dev/null; then
        log_warning "Throughput below threshold: ${requests_per_sec} < ${PERFORMANCE_THROUGHPUT_THRESHOLD} rps"
        perf_passed=false
    fi
    
    if $perf_passed; then
        log_success "Performance Tests: PASSED 🚀"
        exit 0
    else
        log_warning "Performance Tests: THRESHOLDS NOT MET ⚠️"
        exit 1
    fi
else
    log_error "Performance Tests: FAILED ❌"
    exit 1
fi