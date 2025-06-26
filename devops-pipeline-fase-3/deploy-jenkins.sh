#!/bin/bash

# Deploy Jenkins Script
# FASE 3: CI/CD Base con Jenkins

# Configurazioni
JENKINS_HOME="$HOME/jenkins"
JENKINS_PORT="8080"
JENKINS_URL="http://localhost:$JENKINS_PORT"
LOG_FILE="$HOME/deploy-jenkins.log"
CRM_SYSTEM_DIR="$HOME/devops/CRM-System"
PIPELINE_JOBS_DIR="$JENKINS_HOME/jobs"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

# Funzione per verificare se Jenkins è in esecuzione
is_jenkins_running() {
    if sudo systemctl is-active --quiet jenkins; then
        return 0
    fi
    return 1
}

# Funzione per verificare se Jenkins è raggiungibile
is_jenkins_accessible() {
    if curl -s "$JENKINS_URL" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Funzione per attendere che Jenkins sia pronto
wait_for_jenkins() {
    local max_attempts=30
    local attempt=0
    
    log_info "Attendo che Jenkins sia completamente avviato..."
    
    while [ $attempt -lt $max_attempts ]; do
        if is_jenkins_accessible; then
            log_success "Jenkins raggiungibile e pronto"
            return 0
        fi
        
        sleep 10
        ((attempt++))
        log_info "Tentativo $attempt/$max_attempts - attendo Jenkins..."
    done
    
    log_error "Jenkins non raggiungibile dopo $max_attempts tentativi"
    return 1
}

# Funzione per avviare Jenkins
start_jenkins() {
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Start"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Avvio servizio Jenkins..."
    
    if is_jenkins_running; then
        log_info "Jenkins già in esecuzione"
    else
        if sudo systemctl start jenkins; then
            log_success "Servizio Jenkins avviato"
        else
            log_error "Errore nell'avvio di Jenkins"
            return 1
        fi
    fi
    
    # Attendi che Jenkins sia completamente pronto
    if wait_for_jenkins; then
        show_jenkins_info
        return 0
    else
        log_error "Jenkins avviato ma non raggiungibile"
        return 1
    fi
}

# Funzione per fermare Jenkins
stop_jenkins() {
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Stop"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Arresto servizio Jenkins..."
    
    if is_jenkins_running; then
        if sudo systemctl stop jenkins; then
            log_success "Servizio Jenkins arrestato"
        else
            log_error "Errore nell'arresto di Jenkins"
            return 1
        fi
    else
        log_info "Jenkins non era in esecuzione"
    fi
}

# Funzione per riavviare Jenkins
restart_jenkins() {
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Restart"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Riavvio servizio Jenkins..."
    
    if sudo systemctl restart jenkins; then
        log_success "Servizio Jenkins riavviato"
        
        if wait_for_jenkins; then
            show_jenkins_info
            return 0
        else
            log_error "Jenkins riavviato ma non raggiungibile"
            return 1
        fi
    else
        log_error "Errore nel riavvio di Jenkins"
        return 1
    fi
}

# Funzione per mostrare status di Jenkins
show_status() {
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Status"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Status Jenkins:"
    
    # Status servizio
    if is_jenkins_running; then
        log_success "Servizio Jenkins: ATTIVO"
    else
        log_error "Servizio Jenkins: NON ATTIVO"
    fi
    
    # Raggiungibilità
    if is_jenkins_accessible; then
        log_success "Jenkins Web UI: RAGGIUNGIBILE"
        
        # Informazioni versione se disponibili
        local version=$(curl -s "$JENKINS_URL/api/xml?xpath=/hudson/version" 2>/dev/null | sed -n 's|.*<version>\\(.*\\)</version>.*|\\1|p')
        if [ -n "$version" ]; then
            log_info "Versione Jenkins: $version"
        fi
    else
        log_error "Jenkins Web UI: NON RAGGIUNGIBILE"
    fi
    
    # Verifica porte
    echo ""
    log_info "Verifica porte:"
    if lsof -ti:$JENKINS_PORT >/dev/null 2>&1; then
        echo "  - Porta $JENKINS_PORT: OCCUPATA"
        local process=$(lsof -ti:$JENKINS_PORT | head -1 | xargs -r ps -p | tail -n +2)
        echo "  - Processo: $(echo $process | awk '{print $11}')"
    else
        echo "  - Porta $JENKINS_PORT: LIBERA"
    fi
    
    # Jobs configurati
    echo ""
    log_info "Pipeline configurate:"
    if [ -d "$PIPELINE_JOBS_DIR" ]; then
        local job_count=$(find "$PIPELINE_JOBS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "  - Job trovati: $job_count"
        
        if [ $job_count -gt 0 ]; then
            find "$PIPELINE_JOBS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \\; | while read job; do
                echo "    • $job"
            done
        fi
    else
        echo "  - Directory jobs non trovata"
    fi
    
    show_jenkins_info
}

# Funzione per mostrare informazioni di accesso Jenkins
show_jenkins_info() {
    echo ""
    log_info "Informazioni Accesso Jenkins:"
    echo "  • Dashboard: $JENKINS_URL"
    echo "  • Blue Ocean: $JENKINS_URL/blue"
    echo "  • API: $JENKINS_URL/api"
    
    # Password iniziale se disponibile
    local password_file="/var/lib/jenkins/secrets/initialAdminPassword"
    if [ -f "$password_file" ]; then
        local password=$(sudo cat "$password_file" 2>/dev/null)
        if [ -n "$password" ]; then
            echo "  • Password iniziale: $password"
        fi
    fi
    
    if [ -f "$HOME/jenkins-initial-password.txt" ]; then
        echo "  • Password salvata in: $HOME/jenkins-initial-password.txt"
    fi
    
    echo ""
    log_info "Comandi Utili:"
    echo "  • ./deploy-jenkins.sh setup-pipelines    # Configura pipeline CRM"
    echo "  • ./deploy-jenkins.sh logs              # Visualizza logs"
    echo "  • ./test-jenkins.sh                     # Test completi CI/CD"
}

# Funzione per visualizzare logs
show_logs() {
    local service="${1:-jenkins}"
    
    echo ""
    echo "======================================="
    echo "   CRM System - Jenkins Logs"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Visualizzazione logs $service..."
    
    case "$service" in
        "jenkins")
            if sudo systemctl is-active --quiet jenkins; then
                echo ""
                echo "=== JENKINS SERVICE LOGS (ultimi 50) ==="
                sudo journalctl -u jenkins -n 50 --no-pager
                
                echo ""
                echo "=== JENKINS APPLICATION LOGS ==="
                local jenkins_log="/var/log/jenkins/jenkins.log"
                if [ -f "$jenkins_log" ]; then
                    sudo tail -30 "$jenkins_log"
                else
                    log_warning "Log file Jenkins non trovato: $jenkins_log"
                fi
            else
                log_error "Jenkins non è in esecuzione"
            fi
            ;;
        "pipeline")
            log_info "Pipeline logs verranno implementati con i job specifici"
            ;;
        *)
            log_error "Tipo log non riconosciuto: $service"
            echo "Tipi disponibili: jenkins, pipeline"
            ;;
    esac
}

# Funzione per setup pipeline CRM
setup_pipelines() {
    echo ""
    echo "======================================="
    echo "   CRM System - Setup Pipelines"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================="
    
    log_info "Configurazione pipeline CI/CD per CRM..."
    
    # Verifica che Jenkins sia raggiungibile
    if ! is_jenkins_accessible; then
        log_error "Jenkins non raggiungibile. Avvia prima Jenkins con: ./deploy-jenkins.sh start"
        return 1
    fi
    
    # Crea directory per job se non esiste
    mkdir -p "$PIPELINE_JOBS_DIR"
    
    # Qui implementeremo la creazione dei job Jenkins via API o XML
    log_info "Setup pipeline implementazione in corso..."
    log_info "Per ora, configura manualmente i seguenti job in Jenkins:"
    echo ""
    echo "1. CRM-Build-Pipeline:"
    echo "   - Source: $CRM_SYSTEM_DIR"
    echo "   - Branch: main"
    echo "   - Build: Docker build per backend e frontend"
    echo ""
    echo "2. CRM-Test-Pipeline:"
    echo "   - Trigger: Dopo CRM-Build-Pipeline"
    echo "   - Tests: Esegui test FASE 1 e FASE 2"
    echo ""
    echo "3. CRM-Deploy-Pipeline:"
    echo "   - Trigger: Dopo CRM-Test-Pipeline (se successo)"
    echo "   - Deploy: Container deployment automatico"
    echo ""
    
    log_success "Informazioni pipeline generate"
    log_info "Implementazione automatica pipeline sarà aggiunta nelle prossime iterazioni"
}

# Funzione per backup configurazione Jenkins
backup_jenkins() {
    local backup_file="$HOME/jenkins-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    log_info "Backup configurazione Jenkins..."
    
    if [ -d "/var/lib/jenkins" ]; then
        if sudo tar -czf "$backup_file" -C /var/lib jenkins --exclude="jenkins/workspace" --exclude="jenkins/builds" 2>/dev/null; then
            log_success "Backup creato: $backup_file"
            echo "  • Backup file: $backup_file"
            echo "  • Dimensione: $(du -h "$backup_file" | cut -f1)"
        else
            log_error "Errore nella creazione del backup"
            return 1
        fi
    else
        log_error "Directory Jenkins non trovata: /var/lib/jenkins"
        return 1
    fi
}

# Funzione per ripristino configurazione Jenkins
restore_jenkins() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Specificare il file di backup da ripristinare"
        echo "Uso: ./deploy-jenkins.sh restore /path/to/backup.tar.gz"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "File di backup non trovato: $backup_file"
        return 1
    fi
    
    log_info "Ripristino configurazione Jenkins da: $backup_file"
    
    # Ferma Jenkins
    if is_jenkins_running; then
        stop_jenkins
    fi
    
    # Ripristina backup
    if sudo tar -xzf "$backup_file" -C /var/lib/ 2>/dev/null; then
        log_success "Backup ripristinato"
        
        # Riavvia Jenkins
        start_jenkins
    else
        log_error "Errore nel ripristino del backup"
        return 1
    fi
}

# Funzione principale
main() {
    case "${1:-start}" in
        "start")
            start_jenkins
            ;;
        "stop")
            stop_jenkins
            ;;
        "restart")
            restart_jenkins
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-jenkins}"
            ;;
        "setup-pipelines")
            setup_pipelines
            ;;
        "backup")
            backup_jenkins
            ;;
        "restore")
            restore_jenkins "$2"
            ;;
        *)
            echo "Uso: $0 {start|stop|restart|status|logs|setup-pipelines|backup|restore}"
            echo ""
            echo "Comandi disponibili:"
            echo "  start           - Avvia il servizio Jenkins"
            echo "  stop            - Ferma il servizio Jenkins"
            echo "  restart         - Riavvia il servizio Jenkins"
            echo "  status          - Mostra status Jenkins e pipeline"
            echo "  logs [type]     - Visualizza logs (jenkins|pipeline)"
            echo "  setup-pipelines - Configura pipeline CI/CD per CRM"
            echo "  backup          - Backup configurazione Jenkins"
            echo "  restore <file>  - Ripristina backup Jenkins"
            echo ""
            echo "Esempi:"
            echo "  $0 start                    # Avvia Jenkins"
            echo "  $0 logs jenkins             # Mostra logs Jenkins"
            echo "  $0 setup-pipelines          # Configura pipeline CRM"
            echo "  $0 backup                   # Backup configurazione"
            echo ""
            exit 1
            ;;
    esac
}

# Esecuzione script
main "$@"