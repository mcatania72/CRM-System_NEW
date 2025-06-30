#!/bin/bash

# ================================
# AWS MANAGER - CRM SYSTEM
# Script principale per gestione completa AWS deployment
# ================================

set -euo pipefail

# Configurazione
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

echo "=== 🌩️ AWS MANAGER - CRM SYSTEM ==="
echo "Script Directory: $SCRIPT_DIR"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: VERIFICA PREREQUISITI
# ================================
check_prerequisites() {
    log_info "🔍 Verifica prerequisiti..."
    
    # Verifica AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "❌ AWS CLI non installato"
        echo "Installa AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Verifica configurazione AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "❌ AWS non configurato"
        echo "Configura AWS CLI: aws configure"
        exit 1
    fi
    
    # Verifica script AWS
    for script in "aws-setup.sh" "aws-deploy.sh" "aws-monitoring.sh"; do
        if [ ! -f "$AWS_SCRIPTS_DIR/$script" ]; then
            log_error "❌ Script mancante: $script"
            exit 1
        fi
        chmod +x "$AWS_SCRIPTS_DIR/$script"
    done
    
    log_success "✅ Prerequisiti verificati"
}

# ================================
# FUNZIONE: SETUP COMPLETO AWS
# ================================
full_setup() {
    log_header "SETUP COMPLETO AWS"
    
    log_info "🚀 Avvio setup completo AWS..."
    
    # 1. Crea infrastruttura AWS
    log_info "🏗️ Step 1: Creazione infrastruttura AWS..."
    "$AWS_SCRIPTS_DIR/aws-setup.sh" create-instance
    
    # 2. Configura networking
    log_info "🌐 Step 2: Configurazione networking..."
    "$AWS_SCRIPTS_DIR/aws-setup.sh" configure-network
    
    # 3. Attendi setup completato
    log_info "⏳ Step 3: Attesa completamento setup automatico..."
    sleep 60  # Attendi 1 minuto
    
    # 4. Verifica setup
    log_info "🔍 Step 4: Verifica setup AWS..."
    "$AWS_SCRIPTS_DIR/aws-setup.sh" verify
    
    # 5. Deploy applicazione
    log_info "🚀 Step 5: Deploy applicazione CRM..."
    "$AWS_SCRIPTS_DIR/aws-deploy.sh" install
    
    # 6. Setup monitoring
    log_info "📊 Step 6: Setup monitoring e alerts..."
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" alerts
    
    # 7. Backup iniziale
    log_info "💾 Step 7: Backup database iniziale..."
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" backup-database
    
    log_success "✅ Setup completo AWS terminato!"
    show_access_info
}

# ================================
# FUNZIONE: QUICK DEPLOY
# ================================
quick_deploy() {
    log_header "QUICK DEPLOY"
    
    log_info "⚡ Deploy veloce applicazione..."
    
    # Verifica che l'istanza esista
    if ! "$AWS_SCRIPTS_DIR/aws-setup.sh" verify &> /dev/null; then
        log_error "❌ Istanza AWS non trovata"
        echo "Esegui prima: $0 setup"
        exit 1
    fi
    
    # Deploy applicazione
    "$AWS_SCRIPTS_DIR/aws-deploy.sh" install
    
    log_success "✅ Quick deploy completato!"
    show_access_info
}

# ================================
# FUNZIONE: STATUS COMPLETO
# ================================
full_status() {
    log_header "STATUS COMPLETO SISTEMA"
    
    # 1. Status AWS infrastruttura
    log_info "🌩️ Status infrastruttura AWS..."
    "$AWS_SCRIPTS_DIR/aws-setup.sh" verify
    
    echo ""
    
    # 2. Status applicazione
    log_info "🚀 Status applicazione..."
    "$AWS_SCRIPTS_DIR/aws-deploy.sh" status
    
    echo ""
    
    # 3. Monitoring risorse
    log_info "📊 Monitoring risorse..."
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" resources
    
    echo ""
    
    # 4. Health checks
    log_info "🏥 Health checks..."
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" health
    
    show_access_info
}

# ================================
# FUNZIONE: OTTIMIZZAZIONE
# ================================
optimize_system() {
    log_header "OTTIMIZZAZIONE SISTEMA"
    
    log_info "⚡ Ottimizzazione sistema per performance..."
    
    # Ottimizzazione sistema
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" optimize
    
    # Performance analysis
    "$AWS_SCRIPTS_DIR/aws-monitoring.sh" performance
    
    log_success "✅ Ottimizzazione completata!"
}

# ================================
# FUNZIONE: BACKUP E RESTORE
# ================================
backup_restore() {
    local action=${1:-"backup"}
    local backup_file=${2:-""}
    
    log_header "BACKUP E RESTORE"
    
    case $action in
        "backup")
            log_info "💾 Creazione backup database..."
            "$AWS_SCRIPTS_DIR/aws-monitoring.sh" backup-database
            ;;
        "restore")
            if [ -z "$backup_file" ]; then
                log_error "❌ Specificare file di backup"
                echo "Usage: $0 backup restore <backup_file.sql.gz>"
                exit 1
            fi
            log_info "🔄 Restore database da $backup_file..."
            "$AWS_SCRIPTS_DIR/aws-monitoring.sh" restore-database "$backup_file"
            ;;
        *)
            log_error "❌ Azione non valida: $action"
            echo "Azioni disponibili: backup, restore"
            exit 1
            ;;
    esac
    
    log_success "✅ Operazione $action completata!"
}

# ================================
# FUNZIONE: SCALING
# ================================
scale_system() {
    local target=${1:-"t3.small"}
    
    log_header "SCALING SISTEMA"
    
    log_info "📈 Scaling sistema a $target..."
    
    case $target in
        "t3.small")
            log_info "🔄 Upgrade a t3.small (2GB RAM, 2 vCPU)..."
            # Implementa logic scaling
            log_warning "⚠️ Scaling non ancora implementato"
            log_info "📋 Steps manuali:"
            echo "1. Stop istanza corrente"
            echo "2. Cambia instance type a t3.small"
            echo "3. Start istanza"
            echo "4. Rideploy con profilo aws-scaling"
            ;;
        "t3.medium")
            log_info "🔄 Upgrade a t3.medium (4GB RAM, 2 vCPU)..."
            log_warning "⚠️ Scaling non ancora implementato"
            ;;
        *)
            log_error "❌ Target scaling non supportato: $target"
            echo "Target supportati: t3.small, t3.medium"
            exit 1
            ;;
    esac
}

# ================================
# FUNZIONE: CLEANUP
# ================================
cleanup_aws() {
    log_header "CLEANUP RISORSE AWS"
    
    log_warning "⚠️ ATTENZIONE: Questa operazione eliminerà TUTTE le risorse AWS"
    echo "Risorse che verranno eliminate:"
    echo "- Istanza EC2"
    echo "- Elastic IP"
    echo "- Security Group"
    echo "- Key Pair"
    echo "- Tutti i dati dell'applicazione"
    echo ""
    
    read -p "Sei sicuro di voler continuare? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "❌ Operazione annullata"
        exit 0
    fi
    
    log_info "🗑️ Eliminazione risorse AWS..."
    "$AWS_SCRIPTS_DIR/aws-setup.sh" cleanup
    
    log_success "✅ Cleanup AWS completato!"
}

# ================================
# FUNZIONE: SHOW ACCESS INFO
# ================================
show_access_info() {
    # Ottieni IP pubblico istanza
    local public_ip=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=crm-system-instance" "Name=instance-state-name,Values=running" \
        --region "us-east-1" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null || echo "N/A")
    
    if [ "$public_ip" != "N/A" ] && [ "$public_ip" != "None" ]; then
        echo ""
        log_header "INFORMAZIONI ACCESSO"
        echo "🌐 Frontend:     http://$public_ip:30002"
        echo "🔌 Backend API:  http://$public_ip:30003/api"
        echo "🔑 Login:        admin@crm.local / admin123"
        echo "🔐 SSH:          ssh -i crm-key-pair.pem ubuntu@$public_ip"
        echo ""
    fi
}

# ================================
# FUNZIONE: HELP
# ================================
show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "📋 COMANDI PRINCIPALI:"
    echo "  setup              - Setup completo AWS (infrastruttura + deploy)"
    echo "  deploy             - Deploy veloce applicazione"
    echo "  status             - Status completo sistema"
    echo "  optimize           - Ottimizzazione sistema performance"
    echo ""
    echo "💾 BACKUP E RESTORE:"
    echo "  backup backup      - Crea backup database"
    echo "  backup restore     - Restore database da backup"
    echo ""
    echo "📈 SCALING:"
    echo "  scale t3.small     - Scale a istanza più grande"
    echo "  scale t3.medium    - Scale a istanza media"
    echo ""
    echo "🛠️ UTILITY:"
    echo "  cleanup            - Elimina tutte le risorse AWS"
    echo "  help               - Mostra questo help"
    echo ""
    echo "📊 MONITORING:"
    echo "  monitor resources  - Monitor risorse sistema"
    echo "  monitor health     - Health checks applicazione"
    echo "  monitor performance - Analisi performance"
    echo ""
    echo "🔧 SCRIPT DIRETTI:"
    echo "  aws-setup          - Gestione infrastruttura AWS"
    echo "  aws-deploy         - Deploy e gestione applicazione"
    echo "  aws-monitoring     - Monitoring e ottimizzazione"
    echo ""
    echo "📝 ESEMPI:"
    echo "  $0 setup                              # Setup completo"
    echo "  $0 deploy                             # Deploy veloce"
    echo "  $0 status                             # Status sistema"
    echo "  $0 backup backup                      # Backup DB"
    echo "  $0 backup restore crm_backup_*.sql.gz # Restore DB"
    echo "  $0 scale t3.small                     # Scale up"
    echo "  $0 cleanup                            # Elimina tutto"
}

# ================================
# FUNZIONE: MONITORING WRAPPER
# ================================
monitoring_wrapper() {
    local action=${1:-"resources"}
    
    case $action in
        "resources"|"health"|"performance"|"optimize")
            "$AWS_SCRIPTS_DIR/aws-monitoring.sh" "$action"
            ;;
        *)
            log_error "❌ Azione monitoring non valida: $action"
            echo "Azioni disponibili: resources, health, performance, optimize"
            exit 1
            ;;
    esac
}

# ================================
# FUNZIONE: SCRIPT WRAPPER
# ================================
script_wrapper() {
    local script_name=${1:-""}
    shift
    
    case $script_name in
        "aws-setup")
            "$AWS_SCRIPTS_DIR/aws-setup.sh" "$@"
            ;;
        "aws-deploy")
            "$AWS_SCRIPTS_DIR/aws-deploy.sh" "$@"
            ;;
        "aws-monitoring")
            "$AWS_SCRIPTS_DIR/aws-monitoring.sh" "$@"
            ;;
        *)
            log_error "❌ Script non valido: $script_name"
            echo "Script disponibili: aws-setup, aws-deploy, aws-monitoring"
            exit 1
            ;;
    esac
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    # Verifica prerequisiti per tutti i comandi tranne help
    if [ "${1:-help}" != "help" ]; then
        check_prerequisites
    fi
    
    case "${1:-help}" in
        "setup")
            full_setup
            ;;
        "deploy")
            quick_deploy
            ;;
        "status")
            full_status
            ;;
        "optimize")
            optimize_system
            ;;
        "backup")
            backup_restore "${2:-backup}" "${3:-}"
            ;;
        "scale")
            scale_system "${2:-t3.small}"
            ;;
        "cleanup")
            cleanup_aws
            ;;
        "monitor")
            monitoring_wrapper "${2:-resources}"
            ;;
        "aws-setup"|"aws-deploy"|"aws-monitoring")
            script_wrapper "$@"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Esecuzione
main "$@"
