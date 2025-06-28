#!/bin/bash

# ============================================
# Test Advanced - Report Generator Module
# FASE 5: Generazione report completo testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_report() {
    echo -e "${BLUE}[REPORT]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') REPORT: $1" >> ~/test-advanced.log
}

log_report "Generazione report completo..."

# Ensure reports directory exists
mkdir -p "$HOME/testing-workspace/reports"

# Collect test results
REPORT_DIR="$HOME/testing-workspace/reports"
TIMESTAMP=$(date -Iseconds)

# Read test summaries
read_json_value() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        grep "\"$key\"" "$file" | cut -d':' -f2 | tr -d ' ,"' | head -1
    else
        echo "false"
    fi
}

# Collect results
UNIT_RESULT=$(read_json_value "$REPORT_DIR/unit-summary.json" "overall")
INTEGRATION_RESULT=$(read_json_value "$REPORT_DIR/integration-summary.json" "overall")
E2E_RESULT=$(read_json_value "$REPORT_DIR/e2e-summary.json" "overall")
PERFORMANCE_RESULT=$(read_json_value "$REPORT_DIR/performance-summary.json" "overall")
SECURITY_RESULT=$(read_json_value "$REPORT_DIR/security-summary.json" "overall")

# Calculate overall success
if [[ "$UNIT_RESULT" == "true" && "$INTEGRATION_RESULT" == "true" && "$E2E_RESULT" == "true" && "$PERFORMANCE_RESULT" == "true" ]]; then
    OVERALL_SUCCESS="true"
else
    OVERALL_SUCCESS="false"
fi

# Generate JSON report
log_report "Generazione JSON report..."
cat > "$REPORT_DIR/test-results-summary.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "overall_success": $OVERALL_SUCCESS,
  "results": {
    "unit_tests": $UNIT_RESULT,
    "integration_tests": $INTEGRATION_RESULT,
    "e2e_tests": $E2E_RESULT,
    "performance_tests": $PERFORMANCE_RESULT,
    "security_tests": $SECURITY_RESULT
  },
  "details": {
    "unit": "$REPORT_DIR/unit-summary.json",
    "integration": "$REPORT_DIR/integration-summary.json",
    "e2e": "$REPORT_DIR/e2e-summary.json",
    "performance": "$REPORT_DIR/performance-summary.json",
    "security": "$REPORT_DIR/security-summary.json"
  }
}
EOF

# Generate HTML report
log_report "Generazione HTML report..."
cat > "$REPORT_DIR/test-results.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM System - Test Results Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .card h3 { margin: 0 0 15px 0; font-size: 1.2em; }
        .status { padding: 8px 15px; border-radius: 20px; font-weight: bold; display: inline-block; }
        .status.success { background: #d4edda; color: #155724; }
        .status.warning { background: #fff3cd; color: #856404; }
        .status.error { background: #f8d7da; color: #721c24; }
        .overall { grid-column: 1 / -1; text-align: center; }
        .details { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .timestamp { color: #666; font-size: 0.9em; }
        .log-section { margin-top: 20px; }
        .log-section h4 { margin: 0 0 10px 0; }
        .log-content { background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 0.9em; max-height: 200px; overflow-y: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 CRM System - Test Results</h1>
            <p>FASE 5: Enterprise Testing Strategy Dashboard</p>
            <p class="timestamp">Generated: TIMESTAMP_PLACEHOLDER</p>
        </div>
        
        <div class="grid">
            <div class="card overall">
                <h3>🎯 Overall Test Status</h3>
                <div class="status OVERALL_STATUS_CLASS">OVERALL_STATUS_TEXT</div>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>⚡ Unit Tests</h3>
                <div class="status UNIT_STATUS_CLASS">UNIT_STATUS_TEXT</div>
                <p>Backend & Frontend component testing</p>
            </div>
            
            <div class="card">
                <h3>🔗 Integration Tests</h3>
                <div class="status INTEGRATION_STATUS_CLASS">INTEGRATION_STATUS_TEXT</div>
                <p>API, Database & Service integration</p>
            </div>
            
            <div class="card">
                <h3>🎭 E2E Tests</h3>
                <div class="status E2E_STATUS_CLASS">E2E_STATUS_TEXT</div>
                <p>End-to-end user journey testing</p>
            </div>
            
            <div class="card">
                <h3>⚡ Performance Tests</h3>
                <div class="status PERFORMANCE_STATUS_CLASS">PERFORMANCE_STATUS_TEXT</div>
                <p>Load testing & performance metrics</p>
            </div>
            
            <div class="card">
                <h3>🛡️ Security Tests</h3>
                <div class="status SECURITY_STATUS_CLASS">SECURITY_STATUS_TEXT</div>
                <p>Vulnerability scanning & security audit</p>
            </div>
        </div>
        
        <div class="details">
            <h3>📋 Test Execution Details</h3>
            <p><strong>Timestamp:</strong> TIMESTAMP_PLACEHOLDER</p>
            <p><strong>Test Environment:</strong> Testing Pipeline (Ports 3100/3101)</p>
            <p><strong>Report Location:</strong> ~/testing-workspace/reports/</p>
            
            <div class="log-section">
                <h4>📄 Available Reports:</h4>
                <div class="log-content">
                    • Unit Tests: unit-summary.json<br>
                    • Integration Tests: integration-summary.json<br>
                    • E2E Tests: e2e-summary.json<br>
                    • Performance Tests: performance-summary.json<br>
                    • Security Tests: security-summary.json<br>
                    • Overall Summary: test-results-summary.json
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Replace placeholders in HTML
get_status_class() {
    case "$1" in
        "true") echo "success" ;;
        "false") echo "error" ;;
        *) echo "warning" ;;
    esac
}

get_status_text() {
    case "$1" in
        "true") echo "PASSED ✅" ;;
        "false") echo "FAILED ❌" ;;
        *) echo "WARNING ⚠️" ;;
    esac
}

# Update HTML with actual values
sed -i "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/g" "$REPORT_DIR/test-results.html"
sed -i "s/OVERALL_STATUS_CLASS/$(get_status_class "$OVERALL_SUCCESS")/g" "$REPORT_DIR/test-results.html"
sed -i "s/OVERALL_STATUS_TEXT/$(get_status_text "$OVERALL_SUCCESS")/g" "$REPORT_DIR/test-results.html"
sed -i "s/UNIT_STATUS_CLASS/$(get_status_class "$UNIT_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/UNIT_STATUS_TEXT/$(get_status_text "$UNIT_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/INTEGRATION_STATUS_CLASS/$(get_status_class "$INTEGRATION_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/INTEGRATION_STATUS_TEXT/$(get_status_text "$INTEGRATION_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/E2E_STATUS_CLASS/$(get_status_class "$E2E_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/E2E_STATUS_TEXT/$(get_status_text "$E2E_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/PERFORMANCE_STATUS_CLASS/$(get_status_class "$PERFORMANCE_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/PERFORMANCE_STATUS_TEXT/$(get_status_text "$PERFORMANCE_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/SECURITY_STATUS_CLASS/$(get_status_class "$SECURITY_RESULT")/g" "$REPORT_DIR/test-results.html"
sed -i "s/SECURITY_STATUS_TEXT/$(get_status_text "$SECURITY_RESULT")/g" "$REPORT_DIR/test-results.html"

# Generate Markdown report
log_report "Generazione Markdown report..."
cat > "$REPORT_DIR/test-results.md" << EOF
# 🧪 CRM System - Test Results Report

**FASE 5: Enterprise Testing Strategy**

---

## 📊 Overall Status

**Overall Test Status:** $(get_status_text "$OVERALL_SUCCESS")

**Generated:** $TIMESTAMP

---

## 📋 Test Results Summary

| Test Category | Status | Description |
|---------------|--------|-------------|
| ⚡ Unit Tests | $(get_status_text "$UNIT_RESULT") | Backend & Frontend component testing |
| 🔗 Integration Tests | $(get_status_text "$INTEGRATION_RESULT") | API, Database & Service integration |
| 🎭 E2E Tests | $(get_status_text "$E2E_RESULT") | End-to-end user journey testing |
| ⚡ Performance Tests | $(get_status_text "$PERFORMANCE_RESULT") | Load testing & performance metrics |
| 🛡️ Security Tests | $(get_status_text "$SECURITY_RESULT") | Vulnerability scanning & security audit |

---

## 📁 Report Files

- **HTML Dashboard:** [test-results.html](./test-results.html)
- **JSON Summary:** [test-results-summary.json](./test-results-summary.json)
- **Individual Reports:**
  - Unit Tests: [unit-summary.json](./unit-summary.json)
  - Integration Tests: [integration-summary.json](./integration-summary.json)
  - E2E Tests: [e2e-summary.json](./e2e-summary.json)
  - Performance Tests: [performance-summary.json](./performance-summary.json)
  - Security Tests: [security-summary.json](./security-summary.json)

---

## 🎯 Next Steps

### If Tests Passed ✅
- Review performance metrics
- Check security recommendations
- Proceed to production deployment

### If Tests Failed ❌
- Check individual test logs
- Fix failing test cases
- Re-run specific test suites
- Update code and retry

---

*Generated by CRM DevOps Pipeline - FASE 5*
EOF

log_report "✅ Report generato con successo!"
log_report "📄 HTML Report: $REPORT_DIR/test-results.html"
log_report "📄 JSON Summary: $REPORT_DIR/test-results-summary.json"
log_report "📄 Markdown Report: $REPORT_DIR/test-results.md"

exit 0