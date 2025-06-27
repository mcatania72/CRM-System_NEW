#!/bin/bash

# ============================================
# CRM System - Test Reports Generator
# FASE 5: Testing Avanzato
# ============================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "======================================="
echo "   CRM System - Test Reports Generator"
echo "   FASE 5: Testing Avanzato"
echo "======================================="

log_info "Generating comprehensive test reports..."

# Configuration
REPORT_DIR="./reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/comprehensive-report-$TIMESTAMP.html"

# Create reports directory
mkdir -p "$REPORT_DIR"

# Function to analyze test results
analyze_test_results() {
    local test_type="$1"
    local results_path="$2"
    
    if [[ -f "$results_path" ]]; then
        log_info "Analyzing $test_type results from $results_path"
        
        # Extract key metrics based on file type
        if [[ "$results_path" == *.json ]]; then
            # JSON results
            local total_tests=$(jq -r '.numTotalTests // .stats.tests // .tests // 0' "$results_path" 2>/dev/null || echo "0")
            local passed_tests=$(jq -r '.numPassedTests // .stats.passes // .passes // 0' "$results_path" 2>/dev/null || echo "0")
            local failed_tests=$(jq -r '.numFailedTests // .stats.failures // .failures // 0' "$results_path" 2>/dev/null || echo "0")
            
            echo "$test_type:$total_tests:$passed_tests:$failed_tests"
        elif [[ "$results_path" == *.xml ]]; then
            # XML results (JUnit format)
            local total_tests=$(grep -o 'tests="[0-9]*"' "$results_path" | grep -o '[0-9]*' | head -1 || echo "0")
            local failed_tests=$(grep -o 'failures="[0-9]*"' "$results_path" | grep -o '[0-9]*' | head -1 || echo "0")
            local passed_tests=$((total_tests - failed_tests))
            
            echo "$test_type:$total_tests:$passed_tests:$failed_tests"
        else
            echo "$test_type:0:0:0"
        fi
    else
        echo "$test_type:0:0:0"
    fi
}

# Function to analyze coverage reports
analyze_coverage() {
    local coverage_path="$1"
    
    if [[ -f "$coverage_path" ]]; then
        log_info "Analyzing coverage from $coverage_path"
        
        if [[ "$coverage_path" == *.json ]]; then
            local line_coverage=$(jq -r '.total.lines.pct // 0' "$coverage_path" 2>/dev/null || echo "0")
            local branch_coverage=$(jq -r '.total.branches.pct // 0' "$coverage_path" 2>/dev/null || echo "0")
            local function_coverage=$(jq -r '.total.functions.pct // 0' "$coverage_path" 2>/dev/null || echo "0")
            
            echo "$line_coverage:$branch_coverage:$function_coverage"
        else
            echo "0:0:0"
        fi
    else
        echo "0:0:0"
    fi
}

# Function to analyze performance results
analyze_performance() {
    local perf_path="$1"
    
    if [[ -f "$perf_path" ]]; then
        log_info "Analyzing performance from $perf_path"
        
        if [[ "$perf_path" == *.json ]]; then
            # Artillery results
            local avg_response_time=$(jq -r '.aggregate.latency.mean // 0' "$perf_path" 2>/dev/null || echo "0")
            local p95_response_time=$(jq -r '.aggregate.latency.p95 // 0' "$perf_path" 2>/dev/null || echo "0")
            local total_requests=$(jq -r '.aggregate.counters."http.requests" // 0' "$perf_path" 2>/dev/null || echo "0")
            local success_rate=$(jq -r '.aggregate.codes."200" // 0' "$perf_path" 2>/dev/null || echo "0")
            
            echo "$avg_response_time:$p95_response_time:$total_requests:$success_rate"
        else
            echo "0:0:0:0"
        fi
    else
        echo "0:0:0:0"
    fi
}

# Collect test results
log_info "Collecting test results..."

# Unit test results
UNIT_BACKEND_RESULTS=$(analyze_test_results "Unit Backend" "./backend/test-results.json")
UNIT_FRONTEND_RESULTS=$(analyze_test_results "Unit Frontend" "./frontend/test-results.json")

# Integration test results
INTEGRATION_RESULTS=$(analyze_test_results "Integration" "./reports/integration-results.json")

# E2E test results
E2E_RESULTS=$(analyze_test_results "E2E" "./reports/e2e-results.json")

# Coverage analysis
BACKEND_COVERAGE=$(analyze_coverage "./backend/coverage/coverage-summary.json")
FRONTEND_COVERAGE=$(analyze_coverage "./frontend/coverage/coverage-summary.json")

# Performance analysis
PERFORMANCE_RESULTS=$(analyze_performance "./reports/artillery-report.json")

# Function to generate summary statistics
generate_summary() {
    log_info "Generating test summary..."
    
    # Parse results
    IFS=':' read -r unit_backend_total unit_backend_passed unit_backend_failed <<< "$UNIT_BACKEND_RESULTS"
    IFS=':' read -r unit_frontend_total unit_frontend_passed unit_frontend_failed <<< "$UNIT_FRONTEND_RESULTS"
    IFS=':' read -r integration_total integration_passed integration_failed <<< "$INTEGRATION_RESULTS"
    IFS=':' read -r e2e_total e2e_passed e2e_failed <<< "$E2E_RESULTS"
    
    # Calculate totals
    TOTAL_TESTS=$((unit_backend_total + unit_frontend_total + integration_total + e2e_total))
    TOTAL_PASSED=$((unit_backend_passed + unit_frontend_passed + integration_passed + e2e_passed))
    TOTAL_FAILED=$((unit_backend_failed + unit_frontend_failed + integration_failed + e2e_failed))
    
    # Calculate success rate
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        SUCCESS_RATE=$(echo "scale=1; $TOTAL_PASSED * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    else
        SUCCESS_RATE="0"
    fi
    
    # Parse coverage
    IFS=':' read -r backend_line_cov backend_branch_cov backend_func_cov <<< "$BACKEND_COVERAGE"
    IFS=':' read -r frontend_line_cov frontend_branch_cov frontend_func_cov <<< "$FRONTEND_COVERAGE"
    
    # Parse performance
    IFS=':' read -r avg_response p95_response total_requests success_requests <<< "$PERFORMANCE_RESULTS"
}

# Generate the comprehensive report
generate_report() {
    log_info "Generating HTML report..."
    
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM System - Testing Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0 0 10px 0;
            font-size: 2.2em;
        }
        .timestamp {
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            border-radius: 20px;
            display: inline-block;
            margin-top: 10px;
        }
        .content {
            padding: 30px;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }
        .section {
            margin-bottom: 30px;
        }
        .section h2 {
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }
        .test-results {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        .test-card {
            border: 1px solid #ddd;
            border-radius: 6px;
            padding: 15px;
        }
        .test-card h3 {
            margin: 0 0 10px 0;
            color: #333;
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background: #f0f0f0;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #20c997);
            transition: width 0.3s ease;
        }
        .status-success { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-danger { color: #dc3545; }
        .coverage-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
        }
        .performance-metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 15px;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #ddd;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 CRM System - Testing Report</h1>
            <div class="subtitle">FASE 5: Testing Avanzato</div>
            <div class="timestamp">Generated: $(date)</div>
        </div>
        
        <div class="content">
            <div class="summary-grid">
                <div class="metric-card">
                    <div class="metric-value">$TOTAL_TESTS</div>
                    <div class="metric-label">Total Tests</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value status-success">$TOTAL_PASSED</div>
                    <div class="metric-label">Passed</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value status-danger">$TOTAL_FAILED</div>
                    <div class="metric-label">Failed</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$SUCCESS_RATE%</div>
                    <div class="metric-label">Success Rate</div>
                </div>
            </div>
            
            <div class="section">
                <h2>📊 Test Results by Category</h2>
                <div class="test-results">
                    <div class="test-card">
                        <h3>Unit Tests - Backend</h3>
                        <div>Total: $unit_backend_total</div>
                        <div class="status-success">Passed: $unit_backend_passed</div>
                        <div class="status-danger">Failed: $unit_backend_failed</div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $(echo "scale=0; $unit_backend_passed * 100 / ($unit_backend_total + 1)" | bc -l 2>/dev/null || echo "0")%"></div>
                        </div>
                    </div>
                    
                    <div class="test-card">
                        <h3>Unit Tests - Frontend</h3>
                        <div>Total: $unit_frontend_total</div>
                        <div class="status-success">Passed: $unit_frontend_passed</div>
                        <div class="status-danger">Failed: $unit_frontend_failed</div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $(echo "scale=0; $unit_frontend_passed * 100 / ($unit_frontend_total + 1)" | bc -l 2>/dev/null || echo "0")%"></div>
                        </div>
                    </div>
                    
                    <div class="test-card">
                        <h3>Integration Tests</h3>
                        <div>Total: $integration_total</div>
                        <div class="status-success">Passed: $integration_passed</div>
                        <div class="status-danger">Failed: $integration_failed</div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $(echo "scale=0; $integration_passed * 100 / ($integration_total + 1)" | bc -l 2>/dev/null || echo "0")%"></div>
                        </div>
                    </div>
                    
                    <div class="test-card">
                        <h3>E2E Tests</h3>
                        <div>Total: $e2e_total</div>
                        <div class="status-success">Passed: $e2e_passed</div>
                        <div class="status-danger">Failed: $e2e_failed</div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $(echo "scale=0; $e2e_passed * 100 / ($e2e_total + 1)" | bc -l 2>/dev/null || echo "0")%"></div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>📈 Code Coverage</h2>
                <div class="coverage-grid">
                    <div class="test-card">
                        <h3>Backend Coverage</h3>
                        <div>Lines: $backend_line_cov%</div>
                        <div>Branches: $backend_branch_cov%</div>
                        <div>Functions: $backend_func_cov%</div>
                    </div>
                    <div class="test-card">
                        <h3>Frontend Coverage</h3>
                        <div>Lines: $frontend_line_cov%</div>
                        <div>Branches: $frontend_branch_cov%</div>
                        <div>Functions: $frontend_func_cov%</div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>⚡ Performance Metrics</h2>
                <div class="performance-metrics">
                    <div class="test-card">
                        <h3>Response Time</h3>
                        <div>Average: ${avg_response}ms</div>
                        <div>P95: ${p95_response}ms</div>
                    </div>
                    <div class="test-card">
                        <h3>Load Testing</h3>
                        <div>Total Requests: $total_requests</div>
                        <div>Successful: $success_requests</div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>🎯 Quality Assessment</h2>
                <div class="test-card">
                    <h3>Overall Quality Score</h3>
                    <div style="font-size: 1.2em; margin: 15px 0;">
EOF

    # Calculate quality score
    local quality_score=0
    
    # Test success rate (40% weight)
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        quality_score=$(echo "scale=1; $quality_score + ($SUCCESS_RATE * 0.4)" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Coverage (30% weight)
    local avg_coverage=$(echo "scale=1; ($backend_line_cov + $frontend_line_cov) / 2" | bc -l 2>/dev/null || echo "0")
    quality_score=$(echo "scale=1; $quality_score + ($avg_coverage * 0.3)" | bc -l 2>/dev/null || echo "0")
    
    # Performance (30% weight) - assume good if avg response < 500ms
    if [[ $(echo "$avg_response < 500" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        quality_score=$(echo "scale=1; $quality_score + 30" | bc -l 2>/dev/null || echo "0")
    fi
    
    cat >> "$REPORT_FILE" << EOF
                        Quality Score: <span class="status-$(if [[ $(echo "$quality_score >= 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then echo "success"; elif [[ $(echo "$quality_score >= 60" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then echo "warning"; else echo "danger"; fi)">$quality_score/100</span>
                    </div>
                    <div style="margin-top: 20px;">
                        <strong>FASE 5 Status:</strong>
EOF

    if [[ $(echo "$quality_score >= 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo '                        <span class="status-success">✅ COMPLETATA CON SUCCESSO</span>' >> "$REPORT_FILE"
    elif [[ $(echo "$quality_score >= 60" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo '                        <span class="status-warning">⚠️ COMPLETATA CON AVVERTIMENTI</span>' >> "$REPORT_FILE"
    else
        echo '                        <span class="status-danger">❌ RICHIEDE ATTENZIONE</span>' >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>🔗 Useful Links</h2>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                    <a href="http://localhost:3000" target="_blank" style="text-decoration: none;">
                        <div class="test-card" style="border-color: #667eea; cursor: pointer;">
                            <h3>🌐 CRM Frontend</h3>
                            <div>http://localhost:3000</div>
                        </div>
                    </a>
                    <a href="http://localhost:3001/api/health" target="_blank" style="text-decoration: none;">
                        <div class="test-card" style="border-color: #28a745; cursor: pointer;">
                            <h3>💚 API Health</h3>
                            <div>http://localhost:3001/api/health</div>
                        </div>
                    </a>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <div>Generated by CRM Testing Suite - FASE 5: Testing Avanzato</div>
            <div style="margin-top: 10px; font-size: 0.9em;">
                🚀 Ready for <strong>FASE 6: Kubernetes Deployment</strong>
            </div>
        </div>
    </div>
</body>
</html>
EOF
}

# Function to create summary JSON
create_summary_json() {
    log_info "Creating JSON summary..."
    
    cat > "$REPORT_DIR/summary-$TIMESTAMP.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "phase": "FASE 5: Testing Avanzato",
  "summary": {
    "totalTests": $TOTAL_TESTS,
    "passedTests": $TOTAL_PASSED,
    "failedTests": $TOTAL_FAILED,
    "successRate": $SUCCESS_RATE
  },
  "testTypes": {
    "unitBackend": {
      "total": $unit_backend_total,
      "passed": $unit_backend_passed,
      "failed": $unit_backend_failed
    },
    "unitFrontend": {
      "total": $unit_frontend_total,
      "passed": $unit_frontend_passed,
      "failed": $unit_frontend_failed
    },
    "integration": {
      "total": $integration_total,
      "passed": $integration_passed,
      "failed": $integration_failed
    },
    "e2e": {
      "total": $e2e_total,
      "passed": $e2e_passed,
      "failed": $e2e_failed
    }
  },
  "coverage": {
    "backend": {
      "lines": $backend_line_cov,
      "branches": $backend_branch_cov,
      "functions": $backend_func_cov
    },
    "frontend": {
      "lines": $frontend_line_cov,
      "branches": $frontend_branch_cov,
      "functions": $frontend_func_cov
    }
  },
  "performance": {
    "averageResponseTime": $avg_response,
    "p95ResponseTime": $p95_response,
    "totalRequests": $total_requests,
    "successfulRequests": $success_requests
  }
}
EOF
}

# Main execution
generate_summary
generate_report
create_summary_json

echo ""
echo "======================================="
echo "   REPORT GENERATION COMPLETED"
echo "======================================="

log_success "Comprehensive test report generated!"
echo ""
echo "📊 Reports created:"
echo "  • HTML Report: $REPORT_FILE"
echo "  • JSON Summary: $REPORT_DIR/summary-$TIMESTAMP.json"
echo ""
echo "📈 Test Summary:"
echo "  • Total Tests: $TOTAL_TESTS"
echo "  • Passed: $TOTAL_PASSED"
echo "  • Failed: $TOTAL_FAILED"
echo "  • Success Rate: $SUCCESS_RATE%"
echo ""
if [[ $(echo "$SUCCESS_RATE >= 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    log_success "🎉 FASE 5: Testing Avanzato COMPLETATA CON SUCCESSO!"
else
    log_warning "⚠️ FASE 5: Testing completata con avvertimenti"
fi

echo ""
echo "🌐 Open report: file://$PWD/$REPORT_FILE"
echo "🚀 Ready for FASE 6: Kubernetes Deployment"