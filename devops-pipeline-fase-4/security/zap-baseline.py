#!/usr/bin/env python3

# =============================================================================
# OWASP ZAP Baseline Security Scan Script
# FASE 4: Security Baseline
# =============================================================================

import sys
import subprocess
import json
import time
import requests
from datetime import datetime

# Configuration
TARGET_URL = "http://localhost:3000"
REPORT_FORMAT = "json"
OUTPUT_FILE = "/tmp/zap-baseline-report.json"
TIMEOUT = 300  # 5 minutes

def check_target_availability():
    """Check if target application is running"""
    try:
        response = requests.get(TARGET_URL, timeout=10)
        if response.status_code == 200:
            print(f"✅ Target application available at {TARGET_URL}")
            return True
    except Exception as e:
        print(f"❌ Target application not available: {e}")
        return False

def run_zap_baseline():
    """Run OWASP ZAP baseline scan"""
    print("🔍 Starting OWASP ZAP baseline security scan...")
    
    # ZAP baseline command
    zap_cmd = [
        "docker", "run", "--rm",
        "-v", "/tmp:/zap/wrk:rw",
        "-t", "owasp/zap2docker-stable:latest",
        "zap-baseline.py",
        "-t", TARGET_URL,
        "-J", "zap-baseline-report.json",
        "-r", "zap-baseline-report.html"
    ]
    
    try:
        # Run ZAP scan
        result = subprocess.run(
            zap_cmd,
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )
        
        print(f"📊 ZAP scan completed with exit code: {result.returncode}")
        
        # Parse results
        if result.returncode == 0:
            print("✅ No security issues found")
        elif result.returncode == 1:
            print("⚠️  Low severity issues found")
        elif result.returncode == 2:
            print("🔶 Medium severity issues found")
        elif result.returncode == 3:
            print("🔴 High severity issues found")
        else:
            print(f"❌ ZAP scan failed: {result.stderr}")
            
        return result.returncode
        
    except subprocess.TimeoutExpired:
        print(f"❌ ZAP scan timed out after {TIMEOUT} seconds")
        return -1
    except Exception as e:
        print(f"❌ ZAP scan error: {e}")
        return -1

def generate_summary_report():
    """Generate summary security report"""
    report = {
        "timestamp": datetime.now().isoformat(),
        "target": TARGET_URL,
        "scan_type": "OWASP ZAP Baseline",
        "status": "completed",
        "reports": {
            "json": "/tmp/zap-baseline-report.json",
            "html": "/tmp/zap-baseline-report.html"
        }
    }
    
    try:
        # Try to read ZAP JSON report for summary
        with open("/tmp/zap-baseline-report.json", "r") as f:
            zap_data = json.load(f)
            
        # Extract summary information
        if "site" in zap_data and len(zap_data["site"]) > 0:
            alerts = zap_data["site"][0].get("alerts", [])
            
            severity_counts = {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
            
            for alert in alerts:
                risk = alert.get("riskdesc", "")
                if "High" in risk:
                    severity_counts["High"] += 1
                elif "Medium" in risk:
                    severity_counts["Medium"] += 1
                elif "Low" in risk:
                    severity_counts["Low"] += 1
                else:
                    severity_counts["Informational"] += 1
            
            report["vulnerabilities"] = severity_counts
            report["total_alerts"] = len(alerts)
            
    except Exception as e:
        print(f"⚠️  Could not parse ZAP report: {e}")
        report["vulnerabilities"] = {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
        report["total_alerts"] = 0
    
    # Write summary report
    with open("/tmp/zap-security-summary.json", "w") as f:
        json.dump(report, f, indent=2)
    
    print("📋 Security summary report generated: /tmp/zap-security-summary.json")
    return report

def main():
    """Main execution function"""
    print("=======================================")
    print("   OWASP ZAP Security Baseline Scan")
    print("   FASE 4: Security Baseline")
    print("=======================================")
    
    # Check if target is available
    if not check_target_availability():
        print("❌ Cannot proceed with scan - target not available")
        sys.exit(1)
    
    # Wait a bit for application to stabilize
    print("⏳ Waiting for application to stabilize...")
    time.sleep(10)
    
    # Run ZAP baseline scan
    exit_code = run_zap_baseline()
    
    # Generate summary report
    summary = generate_summary_report()
    
    # Print summary
    print("\n=======================================")
    print("   SECURITY SCAN RESULTS")
    print("=======================================")
    
    if "vulnerabilities" in summary:
        vulns = summary["vulnerabilities"]
        print(f"🔴 High Severity: {vulns['High']}")
        print(f"🔶 Medium Severity: {vulns['Medium']}")
        print(f"🔵 Low Severity: {vulns['Low']}")
        print(f"ℹ️  Informational: {vulns['Informational']}")
        print(f"📊 Total Alerts: {summary.get('total_alerts', 0)}")
    
    print(f"\n📁 Reports generated:")
    print(f"   JSON: /tmp/zap-baseline-report.json")
    print(f"   HTML: /tmp/zap-baseline-report.html")
    print(f"   Summary: /tmp/zap-security-summary.json")
    
    # Return appropriate exit code
    if exit_code == 0:
        print("\n✅ Security scan completed successfully - No issues found")
    elif exit_code in [1, 2]:
        print("\n⚠️  Security scan completed - Issues found (review required)")
    elif exit_code == 3:
        print("\n🔴 Security scan completed - High severity issues found (action required)")
    else:
        print("\n❌ Security scan failed")
    
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
