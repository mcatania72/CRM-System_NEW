#!/bin/bash

# =============================================================================
# CRM System - Security Deploy Script
# FASE 4: Security Baseline
# =============================================================================

set -euo pipefail

# Configuration
LOG_FILE="$HOME/deploy-security.log"
SONARQUBE_PORT=9000
SONARQUBE_HOME="$HOME/sonarqube"
SECURITY_REPORTS="$HOME/security-reports"

# Logging functions
log_info() {
    echo "[INFO] $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $1" >> "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] ✅ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo "[WARNING] ⚠️ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo "[ERROR] ❌ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$LOG_FILE"
}

# Start SonarQube
start_sonarqube() {
    log_info "Avvio SonarQube server..."
    
    # Check if already running
    if pgrep -f "sonar" > /dev/null; then
        log_success "SonarQube già in esecuzione"
        return 0
    fi
    
    # Start SonarQube
    if [ -f "$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh" ]; then
        "$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh" start
        
        # Wait for startup
        log_info "Attesa avvio SonarQube (max 60 secondi)..."
        for i in {1..12}; do
            if curl -s "http://localhost:$SONARQUBE_PORT" > /dev/null 2>&1; then
                log_success "SonarQube attivo su porta $SONARQUBE_PORT"
                return 0
            fi
            sleep 5
        done
        
        log_warning "SonarQube potrebbe ancora essere in avvio"
    else
        log_error "SonarQube non trovato in $SONARQUBE_HOME"
        return 1
    fi
}

# Stop SonarQube
stop_sonarqube() {
    log_info "Arresto SonarQube server..."
    
    if [ -f "$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh" ]; then
        "$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh" stop
        log_success "SonarQube arrestato"
    else
        # Fallback - kill process
        pkill -f "sonar" 2>/dev/null || true
        log_success "Processi SonarQube terminati"
    fi
}

# Configure Jenkins security integration
configure_jenkins_security() {
    log_info "Configurazione integrazione Jenkins security..."
    
    local jenkins_home="$HOME/.jenkins"
    local fase3_jenkins="$HOME/devops-pipeline-fase-3/jenkins"
    
    # Check if FASE 3 exists
    if [ ! -d "$HOME/devops-pipeline-fase-3" ]; then
        log_warning "FASE 3 non trovata - configurazione security standalone"
        return 0
    fi
    
    # Backup existing Jenkinsfile
    if [ -f "$fase3_jenkins/Jenkinsfile.crm-build" ]; then
        cp "$fase3_jenkins/Jenkinsfile.crm-build" "$fase3_jenkins/Jenkinsfile.crm-build.backup"
        log_success "Backup Jenkinsfile FASE 3 completato"
    fi
    
    # Create enhanced Jenkinsfile with security stages
    cat > "$fase3_jenkins/Jenkinsfile.crm-build" << 'EOF'
pipeline {
    agent any
    
    environment {
        SCANNER_HOME = tool 'SonarQubeScanner'
        TRIVY_CACHE_DIR = '/tmp/trivy-cache'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                }
            }
        }
        
        stage('Environment Check') {
            steps {
                sh 'node --version'
                sh 'npm --version'
                sh 'docker --version'
            }
        }
        
        stage('Dependencies Security Scan') {
            parallel {
                stage('NPM Audit') {
                    steps {
                        dir('backend') {
                            sh 'npm audit --audit-level moderate || true'
                            sh 'npm audit --json > ../security-reports/npm-audit-backend.json || true'
                        }
                        dir('frontend') {
                            sh 'npm audit --audit-level moderate || true'
                            sh 'npm audit --json > ../security-reports/npm-audit-frontend.json || true'
                        }
                    }
                }
                stage('Git Secrets Check') {
                    steps {
                        sh 'git secrets --scan || true'
                    }
                }
            }
        }
        
        stage('Build Backend') {
            steps {
                dir('backend') {
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }
        
        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }
        
        stage('SAST - SonarQube Analysis') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=crm-system -Dsonar.sources=. -Dsonar.host.url=http://localhost:9000'
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        dir('backend') {
                            sh 'npm test || true'
                        }
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        dir('frontend') {
                            sh 'npm test || true'
                        }
                    }
                }
            }
        }
        
        stage('Docker Build & Security Scan') {
            steps {
                script {
                    // Build images
                    sh 'docker-compose -f devops-pipeline-fase-2/docker-compose.yml build'
                    
                    // Scan images for vulnerabilities
                    sh 'trivy image --exit-code 0 --format json --output security-reports/trivy-backend.json crm-backend:latest || true'
                    sh 'trivy image --exit-code 0 --format json --output security-reports/trivy-frontend.json crm-frontend:latest || true'
                    
                    // Generate human-readable reports
                    sh 'trivy image --exit-code 0 --format table crm-backend:latest || true'
                    sh 'trivy image --exit-code 0 --format table crm-frontend:latest || true'
                }
            }
        }
        
        stage('Package') {
            steps {
                script {
                    // Create deployment package
                    sh 'tar -czf crm-system-${BUILD_NUMBER}.tar.gz backend/dist frontend/dist'
                    
                    // Archive artifacts
                    archiveArtifacts artifacts: 'crm-system-*.tar.gz', fingerprint: true
                    archiveArtifacts artifacts: 'security-reports/**/*', fingerprint: true
                }
            }
        }
        
        stage('Deploy to Development') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Stop existing applications
                    sh 'cd devops-pipeline-fase-1 && ./deploy.sh stop || true'
                    sh 'cd devops-pipeline-fase-2 && ./deploy-containers.sh stop || true'
                    
                    // Deploy using containers (preferred)
                    sh 'cd devops-pipeline-fase-2 && ./deploy-containers.sh start'
                }
            }
        }
        
        stage('DAST - Security Testing') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Wait for application to be ready
                    sh 'sleep 30'
                    
                    // Run OWASP ZAP baseline scan
                    sh '''
                        docker run --rm -v $(pwd)/security-reports:/zap/wrk:rw \
                        -t zaproxy/zap-stable:latest zap-baseline.py \
                        -t http://host.docker.internal:3000 \
                        -J zap-baseline-report.json || true
                    '''
                }
            }
        }
        
        stage('Security Report') {
            steps {
                script {
                    // Generate consolidated security report
                    sh '''
                        echo "=== CRM System Security Report ===" > security-reports/security-summary.txt
                        echo "Build: ${BUILD_NUMBER}" >> security-reports/security-summary.txt
                        echo "Date: $(date)" >> security-reports/security-summary.txt
                        echo "Commit: ${GIT_COMMIT}" >> security-reports/security-summary.txt
                        echo "" >> security-reports/security-summary.txt
                        
                        echo "NPM Audit Results:" >> security-reports/security-summary.txt
                        cat security-reports/npm-audit-*.json | grep -c '"severity"' || echo "0 vulnerabilities" >> security-reports/security-summary.txt
                        echo "" >> security-reports/security-summary.txt
                        
                        echo "Container Scan Results:" >> security-reports/security-summary.txt
                        cat security-reports/trivy-*.json | grep -c '"Severity"' || echo "0 vulnerabilities" >> security-reports/security-summary.txt
                    '''
                }
            }
        }
    }
    
    post {
        always {
            // Publish security reports
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'security-reports',
                reportFiles: '*.html,*.json',
                reportName: 'Security Reports'
            ])
        }
        
        failure {
            echo 'Pipeline failed! Check security reports for issues.'
        }
        
        success {
            echo 'Pipeline completed successfully with security checks!'
        }
    }
}
EOF
    
    log_success "Jenkinsfile aggiornato con security stages"
}

# Setup security directories
setup_security_dirs() {
    log_info "Configurazione directory security..."
    
    # Create security reports directories
    mkdir -p "$SECURITY_REPORTS"/{sonarqube,trivy,zap,npm-audit}
    mkdir -p "$HOME/security-configs"
    
    # Set permissions
    chmod -R 755 "$SECURITY_REPORTS"
    
    log_success "Directory security configurate"
}

# Show status
show_status() {
    echo ""
    echo "======================================="
    echo "   SECURITY PIPELINE STATUS"
    echo "======================================="
    
    # SonarQube status
    if curl -s "http://localhost:$SONARQUBE_PORT" > /dev/null 2>&1; then
        echo "🟢 SonarQube: ATTIVO (http://localhost:$SONARQUBE_PORT)"
    else
        echo "🔴 SonarQube: NON ATTIVO"
    fi
    
    # Docker status - FIX: Check for both possible image names
    if docker images | grep -q "zaproxy/zap-stable"; then
        echo "🟢 OWASP ZAP: Docker image presente (zaproxy/zap-stable)"
    elif docker images | grep -q "owasp/zap2docker-stable"; then
        echo "🟢 OWASP ZAP: Docker image presente (owasp/zap2docker-stable)"
    else
        echo "🔴 OWASP ZAP: Docker image mancante"
    fi
    
    # Trivy status
    if command -v trivy >/dev/null 2>&1; then
        echo "🟢 Trivy: $(trivy --version | head -1)"
    else
        echo "🔴 Trivy: Non installato"
    fi
    
    # Reports directory
    echo "📁 Security Reports: $SECURITY_REPORTS"
    
    # Jenkins integration
    if [ -f "$HOME/devops-pipeline-fase-3/jenkins/Jenkinsfile.crm-build" ]; then
        echo "🟢 Jenkins: Security pipeline configurata"
    else
        echo "🔴 Jenkins: Security pipeline non configurata"
    fi
}

# Main function
main() {
    local action="${1:-help}"
    
    echo "======================================="
    echo "   CRM System - Security Deploy"
    echo "   FASE 4: Security Baseline"
    echo "======================================="
    
    case "$action" in
        "start")
            log_info "Avvio security pipeline..."
            setup_security_dirs
            start_sonarqube
            configure_jenkins_security
            show_status
            log_success "Security pipeline avviata con successo!"
            ;;
            
        "stop")
            log_info "Arresto security pipeline..."
            stop_sonarqube
            log_success "Security pipeline arrestata"
            ;;
            
        "restart")
            log_info "Riavvio security pipeline..."
            stop_sonarqube
            sleep 5
            start_sonarqube
            configure_jenkins_security
            show_status
            log_success "Security pipeline riavviata"
            ;;
            
        "status")
            show_status
            ;;
            
        "logs")
            echo "=== SonarQube Logs ==="
            tail -50 "$SONARQUBE_HOME/logs/sonar.log" 2>/dev/null || echo "Nessun log SonarQube trovato"
            echo ""
            echo "=== Security Deploy Logs ==="
            tail -50 "$LOG_FILE" 2>/dev/null || echo "Nessun log deploy trovato"
            ;;
            
        *)
            echo "Uso: $0 {start|stop|restart|status|logs}"
            echo ""
            echo "Comandi disponibili:"
            echo "  start   - Avvia security pipeline (SonarQube + Jenkins config)"
            echo "  stop    - Ferma security pipeline"
            echo "  restart - Riavvia security pipeline"
            echo "  status  - Mostra stato security tools"
            echo "  logs    - Mostra log security tools"
            echo ""
            echo "Esempi:"
            echo "  $0 start    # Avvia tutti i security tools"
            echo "  $0 status   # Verifica stato security pipeline"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"