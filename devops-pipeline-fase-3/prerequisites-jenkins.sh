#!/bin/bash

# Prerequisites Jenkins Script
# FASE 3: CI/CD Base con Jenkins

LOG_FILE="$HOME/prerequisites-jenkins.log"
JENKINS_HOME="$HOME/jenkins"
JAVA_VERSION="17"

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

# Funzione per verificare se un comando esiste
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Funzione per verificare versione Java
check_java_version() {
    if command_exists java; then
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [ "$java_version" -ge "$JAVA_VERSION" ]; then
            return 0
        fi
    fi
    return 1
}

# Funzione per installare Java
install_java() {
    log_info "🚀 Installazione OpenJDK $JAVA_VERSION..."
    
    # Aggiorna repositories
    sudo apt update
    
    # Installa OpenJDK
    if sudo apt install -y openjdk-${JAVA_VERSION}-jdk; then
        log_success "OpenJDK $JAVA_VERSION installato con successo"
        
        # Configura JAVA_HOME
        local java_home="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
        if [ -d "$java_home" ]; then
            echo "export JAVA_HOME=$java_home" >> ~/.bashrc
            echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
            export JAVA_HOME="$java_home"
            export PATH="$JAVA_HOME/bin:$PATH"
            log_success "JAVA_HOME configurato: $java_home"
        fi
        
        return 0
    else
        log_error "Fallimento installazione OpenJDK $JAVA_VERSION"
        return 1
    fi
}

# Funzione per installare Jenkins
install_jenkins() {
    log_info "🚀 Installazione Jenkins..."
    
    # Aggiungi chiave GPG Jenkins
    if curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null; then
        log_success "Chiave GPG Jenkins aggiunta"
    else
        log_error "Fallimento aggiunta chiave GPG Jenkins"
        return 1
    fi
    
    # Aggiungi repository Jenkins
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    # Aggiorna repositories
    sudo apt update
    
    # Installa Jenkins
    if sudo apt install -y jenkins; then
        log_success "Jenkins installato con successo"
        
        # Abilita e avvia Jenkins
        sudo systemctl enable jenkins
        sudo systemctl start jenkins
        
        # Verifica che Jenkins sia attivo
        if sudo systemctl is-active --quiet jenkins; then
            log_success "Servizio Jenkins avviato correttamente"
        else
            log_warning "Jenkins installato ma non avviato automaticamente"
        fi
        
        return 0
    else
        log_error "Fallimento installazione Jenkins"
        return 1
    fi
}

# Funzione per installare Git (se mancante)
install_git() {
    log_info "🚀 Installazione Git..."
    
    if sudo apt install -y git; then
        log_success "Git installato con successo"
        return 0
    else
        log_error "Fallimento installazione Git"
        return 1
    fi
}

# Funzione per configurare Jenkins
configure_jenkins() {
    log_info "🔧 Configurazione iniziale Jenkins..."
    
    # Crea directory Jenkins home se non esiste
    mkdir -p "$JENKINS_HOME"
    
    # Attendi che Jenkins sia completamente avviato
    local retries=0
    while [ $retries -lt 30 ]; do
        if curl -s http://localhost:8080 >/dev/null 2>&1; then
            log_success "Jenkins raggiungibile su porta 8080"
            break
        fi
        sleep 10
        ((retries++))
        log_info "Attendo avvio Jenkins... ($retries/30)"
    done
    
    if [ $retries -eq 30 ]; then
        log_warning "Jenkins potrebbe non essere completamente avviato"
    fi
    
    # Mostra password iniziale se disponibile
    local initial_password_file="/var/lib/jenkins/secrets/initialAdminPassword"
    if [ -f "$initial_password_file" ]; then
        local initial_password=$(sudo cat "$initial_password_file" 2>/dev/null)
        if [ -n "$initial_password" ]; then
            log_info "Password iniziale Jenkins: $initial_password"
            echo "$initial_password" > "$HOME/jenkins-initial-password.txt"
            log_info "Password salvata in: $HOME/jenkins-initial-password.txt"
        fi
    fi
}

# Funzione per verificare porte necessarie
check_ports() {
    log_info "Verifica porte necessarie..."
    
    # Porta 8080 per Jenkins
    if lsof -ti:8080 >/dev/null 2>&1; then
        local process=$(lsof -ti:8080 | xargs -r ps -p | tail -n +2)
        if echo "$process" | grep -q jenkins; then
            log_success "Porta 8080 occupata da Jenkins ✓"
        else
            log_warning "Porta 8080 occupata da altro processo"
            echo "Processo: $process"
        fi
    else
        log_info "Porta 8080 libera per Jenkins"
    fi
}

# Funzione principale
main() {
    echo ""
    echo "======================================"
    echo "   CRM System - Prerequisites Jenkins"
    echo "   FASE 3: CI/CD Base con Jenkins"
    echo "======================================"
    
    log_info "Verifica prerequisiti Jenkins per FASE 3..."
    
    local missing_items=()
    
    # Verifica Java
    if check_java_version; then
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        log_success "Java trovato: $java_version"
    else
        log_error "Java $JAVA_VERSION+ non trovato"
        missing_items+=("Java")
    fi
    
    # Verifica Jenkins
    if command_exists jenkins; then
        local jenkins_version=$(jenkins --version 2>/dev/null || echo "unknown")
        log_success "Jenkins trovato: $jenkins_version"
        
        # Verifica che il servizio sia attivo
        if sudo systemctl is-active --quiet jenkins; then
            log_success "Servizio Jenkins attivo"
        else
            log_warning "Jenkins installato ma servizio non attivo"
            missing_items+=("Jenkins Service")
        fi
    else
        log_error "Jenkins non trovato"
        missing_items+=("Jenkins")
    fi
    
    # Verifica Git
    if command_exists git; then
        local git_version=$(git --version | cut -d' ' -f3)
        log_success "Git trovato: $git_version"
    else
        log_error "Git non trovato"
        missing_items+=("Git")
    fi
    
    # Verifica Docker (già dovrebbe esserci da FASE 2)
    if command_exists docker; then
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log_success "Docker trovato: $docker_version"
    else
        log_warning "Docker non trovato (dovrebbe essere installato dalla FASE 2)"
    fi
    
    # Verifica Docker Compose
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose trovato"
    else
        log_warning "Docker Compose non trovato"
    fi
    
    # Verifica prerequisiti FASE 1 e 2
    if [ -d "$HOME/devops-pipeline-fase-1" ]; then
        log_success "FASE 1 presente"
    else
        log_warning "FASE 1 non trovata in $HOME/devops-pipeline-fase-1"
    fi
    
    if [ -d "$HOME/devops-pipeline-fase-2" ]; then
        log_success "FASE 2 presente"
    else
        log_warning "FASE 2 non trovata in $HOME/devops-pipeline-fase-2"
    fi
    
    # Installazione automatica se ci sono prerequisiti mancanti
    if [ ${#missing_items[@]} -gt 0 ]; then
        log_warning "Prerequisiti mancanti rilevati:"
        for item in "${missing_items[@]}"; do
            echo "  - $item"
        done
        
        echo ""
        log_info "🚀 AVVIO INSTALLAZIONE AUTOMATICA..."
        
        # Installa Java se mancante
        if [[ " ${missing_items[@]} " =~ " Java " ]]; then
            if ! install_java; then
                log_error "Fallimento installazione Java"
                exit 1
            fi
        fi
        
        # Installa Git se mancante
        if [[ " ${missing_items[@]} " =~ " Git " ]]; then
            if ! install_git; then
                log_error "Fallimento installazione Git"
                exit 1
            fi
        fi
        
        # Installa Jenkins se mancante
        if [[ " ${missing_items[@]} " =~ " Jenkins " ]]; then
            if ! install_jenkins; then
                log_error "Fallimento installazione Jenkins"
                exit 1
            fi
        fi
        
        # Avvia Jenkins se il servizio non è attivo
        if [[ " ${missing_items[@]} " =~ " Jenkins Service " ]]; then
            log_info "Avvio servizio Jenkins..."
            sudo systemctl start jenkins
            if sudo systemctl is-active --quiet jenkins; then
                log_success "Servizio Jenkins avviato"
            else
                log_error "Fallimento avvio servizio Jenkins"
                exit 1
            fi
        fi
        
        # Configurazione Jenkins
        configure_jenkins
    fi
    
    # Verifica porte
    check_ports
    
    echo ""
    echo "======================================="
    echo "   VERIFICA PREREQUISITI COMPLETATA"
    echo "======================================="
    log_success "✅ Tutti i prerequisiti per FASE 3 sono soddisfatti!"
    
    echo "Sistema pronto per CI/CD:"
    echo "- Java: $(java -version 2>&1 | head -n 1 | cut -d'"' -f2)"
    echo "- Jenkins: $(jenkins --version 2>/dev/null || echo 'installato')"
    echo "- Git: $(git --version | cut -d' ' -f3)"
    if command_exists docker; then
        echo "- Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    fi
    echo "- FASE 1: $([ -d "$HOME/devops-pipeline-fase-1" ] && echo 'Presente' || echo 'Non trovata')"
    echo "- FASE 2: $([ -d "$HOME/devops-pipeline-fase-2" ] && echo 'Presente' || echo 'Non trovata')"
    
    echo ""
    echo "Prossimi passi:"
    echo "1. ./deploy-jenkins.sh start    # Configura e avvia pipeline"
    echo "2. ./test-jenkins.sh            # Esegue test CI/CD completi"
    
    # Informazioni accesso Jenkins
    if [ -f "$HOME/jenkins-initial-password.txt" ]; then
        echo ""
        echo "Jenkins Dashboard: http://localhost:8080"
        echo "Password iniziale: $(cat $HOME/jenkins-initial-password.txt)"
        log_info "Per accedere a Jenkins la prima volta, usa la password sopra"
    fi
    
    log "Prerequisites Jenkins check completed successfully"
}

# Esecuzione script
main "$@"