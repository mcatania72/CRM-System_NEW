#!/bin/bash

# ============================================
# CRM System - Test Cleanup Script
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
echo "   CRM System - Test Cleanup"
echo "   FASE 5: Testing Avanzato"
echo "======================================="

log_info "Starting test environment cleanup..."

# Usage function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --all         Clean everything (default)"
    echo "  --reports     Clean only test reports"
    echo "  --artifacts   Clean only test artifacts"
    echo "  --data        Clean only test data"
    echo "  --cache       Clean only cache files"
    echo "  --logs        Clean only log files"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all       # Clean everything"
    echo "  $0 --reports   # Clean only reports"
    exit 1
}

# Parse command line arguments
CLEAN_REPORTS=false
CLEAN_ARTIFACTS=false
CLEAN_DATA=false
CLEAN_CACHE=false
CLEAN_LOGS=false
CLEAN_ALL=true

if [[ $# -gt 0 ]]; then
    CLEAN_ALL=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                CLEAN_ALL=true
                shift
                ;;
            --reports)
                CLEAN_REPORTS=true
                shift
                ;;
            --artifacts)
                CLEAN_ARTIFACTS=true
                shift
                ;;
            --data)
                CLEAN_DATA=true
                shift
                ;;
            --cache)
                CLEAN_CACHE=true
                shift
                ;;
            --logs)
                CLEAN_LOGS=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
fi

# If --all is specified, set all cleanup flags
if [[ "$CLEAN_ALL" == "true" ]]; then
    CLEAN_REPORTS=true
    CLEAN_ARTIFACTS=true
    CLEAN_DATA=true
    CLEAN_CACHE=true
    CLEAN_LOGS=true
fi

# Function to get directory size
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sh "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Function to clean test reports
clean_test_reports() {
    if [[ "$CLEAN_REPORTS" == "true" ]]; then
        log_info "Cleaning test reports..."
        
        local dirs_to_clean=(
            "./reports"
            "./test-results"
            "./coverage"
            "./backend/coverage"
            "./frontend/coverage"
            "./testing/e2e/test-results"
            "./testing/e2e/playwright-report"
        )
        
        local total_size=0
        
        for dir in "${dirs_to_clean[@]}"; do
            if [[ -d "$dir" ]]; then
                local size=$(get_dir_size "$dir")
                log_info "Removing $dir ($size)"
                rm -rf "$dir"
                log_success "Removed $dir"
            fi
        done
        
        # Clean individual report files
        local files_to_clean=(
            "./junit.xml"
            "./test-report.xml"
            "./lighthouse-report.html"
            "./artillery-report.json"
        )
        
        for file in "${files_to_clean[@]}"; do
            if [[ -f "$file" ]]; then
                log_info "Removing $file"
                rm -f "$file"
            fi
        done
        
        log_success "Test reports cleanup completed"
    fi
}

# Function to clean test artifacts
clean_test_artifacts() {
    if [[ "$CLEAN_ARTIFACTS" == "true" ]]; then
        log_info "Cleaning test artifacts..."
        
        local dirs_to_clean=(
            "./screenshots"
            "./videos"
            "./testing/e2e/screenshots"
            "./testing/e2e/videos"
            "./artifacts"
            "./.nyc_output"
            "./.vitest"
        )
        
        for dir in "${dirs_to_clean[@]}"; do
            if [[ -d "$dir" ]]; then
                local size=$(get_dir_size "$dir")
                log_info "Removing $dir ($size)"
                rm -rf "$dir"
                log_success "Removed $dir"
            fi
        done
        
        # Clean Playwright artifacts
        if command -v npx >/dev/null 2>&1; then
            log_info "Cleaning Playwright cache..."
            npx playwright cache clear >/dev/null 2>&1 || log_warning "Failed to clear Playwright cache"
        fi
        
        log_success "Test artifacts cleanup completed"
    fi
}

# Function to clean test data
clean_test_data() {
    if [[ "$CLEAN_DATA" == "true" ]]; then
        log_info "Cleaning test data..."
        
        local files_to_clean=(
            "./test-data/temp-*.json"
            "./test-data/generated-*.json"
            "./test-database.sqlite"
            "./test.db"
        )
        
        for pattern in "${files_to_clean[@]}"; do
            for file in $pattern; do
                if [[ -f "$file" ]]; then
                    log_info "Removing $file"
                    rm -f "$file"
                fi
            done
        done
        
        # Clean temporary test directories
        local temp_dirs=(
            "./tmp"
            "./temp"
            "./.tmp"
            "./testing-workspace/tmp"
        )
        
        for dir in "${temp_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local size=$(get_dir_size "$dir")
                log_info "Removing temporary directory $dir ($size)"
                rm -rf "$dir"
            fi
        done
        
        log_success "Test data cleanup completed"
    fi
}

# Function to clean cache files
clean_cache_files() {
    if [[ "$CLEAN_CACHE" == "true" ]]; then
        log_info "Cleaning cache files..."
        
        # Node.js cache directories
        local cache_dirs=(
            "./node_modules/.cache"
            "./backend/node_modules/.cache"
            "./frontend/node_modules/.cache"
            "./.vite"
            "./backend/.vite"
            "./frontend/.vite"
            "./.jest"
            "./backend/.jest"
            "./frontend/.jest"
        )
        
        for dir in "${cache_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local size=$(get_dir_size "$dir")
                log_info "Removing cache directory $dir ($size)"
                rm -rf "$dir"
            fi
        done
        
        # Clean npm cache (if needed)
        if command -v npm >/dev/null 2>&1; then
            log_info "Verifying npm cache..."
            npm cache verify >/dev/null 2>&1 || log_warning "npm cache verification failed"
        fi
        
        log_success "Cache cleanup completed"
    fi
}

# Function to clean log files
clean_log_files() {
    if [[ "$CLEAN_LOGS" == "true" ]]; then
        log_info "Cleaning log files..."
        
        # Log files and directories
        local log_paths=(
            "./logs"
            "./testing/logs"
            "*.log"
            "./backend/*.log"
            "./frontend/*.log"
            "~/test-*.log"
            "~/testing-*.log"
            "~/deploy-testing.log"
            "~/prerequisites-testing.log"
        )
        
        for pattern in "${log_paths[@]}"; do
            if [[ -d "$pattern" ]]; then
                local size=$(get_dir_size "$pattern")
                log_info "Removing log directory $pattern ($size)"
                rm -rf "$pattern"
            else
                for file in $pattern; do
                    if [[ -f "$file" ]]; then
                        log_info "Removing log file $file"
                        rm -f "$file"
                    fi
                done
            fi
        done
        
        log_success "Log files cleanup completed"
    fi
}

# Function to stop running test processes
stop_test_processes() {
    log_info "Stopping running test processes..."
    
    # Kill test-related processes
    local test_processes=(
        "jest"
        "vitest"
        "playwright"
        "artillery"
        "lighthouse"
        "cypress"
    )
    
    for process in "${test_processes[@]}"; do
        if pgrep -f "$process" >/dev/null 2>&1; then
            log_info "Stopping $process processes..."
            pkill -f "$process" 2>/dev/null || log_warning "Failed to stop $process processes"
        fi
    done
    
    # Stop test database if running
    if docker ps | grep -q "test-db"; then
        log_info "Stopping test database container..."
        docker stop test-db >/dev/null 2>&1 || log_warning "Failed to stop test database"
        docker rm test-db >/dev/null 2>&1 || log_warning "Failed to remove test database container"
    fi
    
    log_success "Test processes cleanup completed"
}

# Function to clean browser data
clean_browser_data() {
    log_info "Cleaning browser test data..."
    
    # Chrome/Chromium test data
    local browser_dirs=(
        "~/.config/google-chrome/Test*"
        "~/.config/chromium/Test*"
        "./testing/e2e/.cache"
    )
    
    for pattern in "${browser_dirs[@]}"; do
        for dir in $pattern; do
            if [[ -d "$dir" ]]; then
                log_info "Removing browser test data: $dir"
                rm -rf "$dir" 2>/dev/null || log_warning "Failed to remove $dir"
            fi
        done
    done
    
    log_success "Browser data cleanup completed"
}

# Function to show cleanup summary
show_cleanup_summary() {
    echo ""
    echo "======================================="
    echo "   CLEANUP SUMMARY"
    echo "======================================="
    
    log_info "Cleanup operations performed:"
    
    if [[ "$CLEAN_REPORTS" == "true" ]]; then
        echo "  ✅ Test reports and coverage files"
    fi
    
    if [[ "$CLEAN_ARTIFACTS" == "true" ]]; then
        echo "  ✅ Test artifacts (screenshots, videos)"
    fi
    
    if [[ "$CLEAN_DATA" == "true" ]]; then
        echo "  ✅ Temporary test data"
    fi
    
    if [[ "$CLEAN_CACHE" == "true" ]]; then
        echo "  ✅ Cache files and directories"
    fi
    
    if [[ "$CLEAN_LOGS" == "true" ]]; then
        echo "  ✅ Log files"
    fi
    
    echo "  ✅ Running test processes"
    echo "  ✅ Browser test data"
    
    echo ""
    log_success "Test environment cleanup completed!"
    echo ""
    echo "💡 Tips for maintaining clean test environment:"
    echo "  • Run cleanup regularly after test sessions"
    echo "  • Use --reports option for quick report cleanup"
    echo "  • Monitor disk space usage with: df -h"
    echo "  • Clean node_modules if needed: rm -rf */node_modules"
    echo ""
    log_success "Test environment is ready for fresh testing! 🧪"
}

# Main execution
echo ""
log_info "Cleanup configuration:"
echo "  • Reports: $(if [[ "$CLEAN_REPORTS" == "true" ]]; then echo "✅"; else echo "❌"; fi)"
echo "  • Artifacts: $(if [[ "$CLEAN_ARTIFACTS" == "true" ]]; then echo "✅"; else echo "❌"; fi)"
echo "  • Test Data: $(if [[ "$CLEAN_DATA" == "true" ]]; then echo "✅"; else echo "❌"; fi)"
echo "  • Cache: $(if [[ "$CLEAN_CACHE" == "true" ]]; then echo "✅"; else echo "❌"; fi)"
echo "  • Logs: $(if [[ "$CLEAN_LOGS" == "true" ]]; then echo "✅"; else echo "❌"; fi)"
echo ""

# Ask for confirmation if cleaning everything
if [[ "$CLEAN_ALL" == "true" ]]; then
    read -p "This will clean ALL test files and artifacts. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
fi

# Perform cleanup operations
stop_test_processes
clean_test_reports
clean_test_artifacts
clean_test_data
clean_cache_files
clean_log_files
clean_browser_data

# Show summary
show_cleanup_summary

log_info "Cleanup script completed. Logs saved to cleanup logs if any."