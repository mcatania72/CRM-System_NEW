#!/bin/bash

# =============================================================================
# DEPLOY INFRASTRUCTURE SCRIPT - FASE 7
# =============================================================================
# Crea 3 VM VMware con cluster Kubernetes distribuito usando Terraform
# =============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
LOG_FILE="$SCRIPT_DIR/infrastructure-deploy.log"

# Funzioni di utility
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

print_header() {
    echo ""
    echo "=============================================="
    echo "  DEPLOY INFRASTRUCTURE - FASE 7"
    echo "  Infrastructure as Code with Terraform"
    echo "=============================================="
    echo ""
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

check_prerequisites() {
    log_info "Controllo prerequisiti..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform non installato!"
        log_info "Esegui: ./prerequisites.sh"
        exit 1
    fi
    
    # Check VMware
    if ! command -v vmrun &> /dev/null; then
        log_error "VMware Workstation non installato!"
        log_info "Installa VMware Workstation Pro"
        exit 1
    fi
    
    # Check Ubuntu ISO
    ISO_PATH="/home/$(whoami)/Downloads/ubuntu-22.04.3-desktop-amd64.iso"
    if [ ! -f "$ISO_PATH" ]; then
        log_warning "Ubuntu ISO non trovato: $ISO_PATH"
        log_info "Download da: https://ubuntu.com/download/desktop"
        
        # Ask user for ISO path
        read -p "Inserisci percorso ISO Ubuntu 22.04: " USER_ISO_PATH
        if [ -f "$USER_ISO_PATH" ]; then
            ISO_PATH="$USER_ISO_PATH"
            log_success "ISO trovato: $ISO_PATH"
        else
            log_error "ISO non trovato: $USER_ISO_PATH"
            exit 1
        fi
    fi
    
    # Check system resources
    check_system_resources
    
    log_success "Prerequisiti verificati"
}

check_system_resources() {
    log_info "Controllo risorse sistema..."
    
    # RAM check (minimo 16GB raccomandato)
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_warning "RAM disponibile: ${TOTAL_RAM}GB (raccomandato: 16GB+)"
        read -p "Continuare comunque? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "RAM disponibile: ${TOTAL_RAM}GB ✅"
    fi
    
    # CPU cores check
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 4 ]; then
        log_warning "CPU cores: $CPU_CORES (raccomandato: 4+)"
    else
        log_success "CPU cores: $CPU_CORES ✅"
    fi
    
    # Disk space check (minimo 100GB)
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 100 ]; then
        log_warning "Spazio disco: ${AVAILABLE_SPACE}GB (raccomandato: 100GB+)"
    else
        log_success "Spazio disco: ${AVAILABLE_SPACE}GB ✅"
    fi
}

check_network_availability() {
    log_info "Controllo disponibilità IP..."
    
    # Check target IPs
    TARGET_IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")
    for ip in "${TARGET_IPS[@]}"; do
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            log_error "IP $ip già in uso!"
            log_info "Libera l'indirizzo IP o modifica la configurazione"
            exit 1
        else
            log_success "IP $ip disponibile ✅"
        fi
    done
}

# =============================================================================
# TERRAFORM OPERATIONS
# =============================================================================

prepare_terraform() {
    log_info "Preparazione configurazione Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Create terraform.tfvars with user-specific values
    cat > terraform.tfvars << EOF
# VM Configuration
vm_base_name = "SPESE"

# Network Configuration
vm_network = {
  subnet  = "192.168.1.0/24"
  gateway = "192.168.1.1"
  dns     = ["8.8.8.8", "8.8.4.4"]
}

# VM Specifications
vm_specs = {
  memory_gb = 4
  cpu_cores = 2
  disk_gb   = 25
}

# Ubuntu ISO Path
ubuntu_iso_path = "$ISO_PATH"

# VM Credentials
vm_credentials = {
  username = "devops"
  password = "devops123"
}
EOF
    
    log_success "Configurazione Terraform preparata"
}

terraform_plan() {
    log_info "Esecuzione Terraform plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Validate configuration
    terraform validate
    
    # Plan deployment
    terraform plan -out=tfplan
    
    log_success "Terraform plan completato"
}

terraform_apply() {
    log_info "Avvio deployment infrastruttura..."
    
    cd "$TERRAFORM_DIR"
    
    # Show plan summary
    echo ""
    log_info "📋 DEPLOYMENT SUMMARY:"
    echo ""
    echo "   🖥️  3 VM VMware verranno create:"
    echo "      • SPESE_FE_VM (192.168.1.101) - Master + Frontend"
    echo "      • SPESE_BE_VM (192.168.1.102) - Worker + Backend" 
    echo "      • SPESE_DB_VM (192.168.1.103) - Worker + Database"
    echo ""
    echo "   ⚡ Specifiche per VM:"
    echo "      • CPU: 2 cores"
    echo "      • RAM: 4GB"
    echo "      • Disk: 25GB (dynamic)"
    echo "      • OS: Ubuntu 22.04 LTS"
    echo ""
    echo "   ☸️  Kubernetes cluster:"
    echo "      • Master node: SPESE_FE_VM"
    echo "      • Worker nodes: SPESE_BE_VM, SPESE_DB_VM"
    echo "      • CNI: Flannel"
    echo "      • Load Balancer: MetalLB"
    echo ""
    
    read -p "Confermi il deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment annullato"
        exit 0
    fi
    
    # Apply Terraform configuration
    log_info "Avvio creazione infrastruttura... (questo richiederà 30-45 minuti)"
    terraform apply tfplan
    
    log_success "Terraform apply completato"
}

# =============================================================================
# POST-DEPLOYMENT VERIFICATION
# =============================================================================

verify_vm_creation() {
    log_info "Verifica creazione VM..."
    
    # Check VM files exist
    VM_DIR="$HOME/VMware_VMs"
    VMS=("SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM")
    
    for vm in "${VMS[@]}"; do
        if [ -f "$VM_DIR/$vm/$vm.vmx" ]; then
            log_success "✅ $vm VMX file creato"
        else
            log_error "❌ $vm VMX file mancante"
        fi
    done
}

verify_vm_connectivity() {
    log_info "Verifica connettività VM..."
    
    IPS=("192.168.1.101" "192.168.1.102" "192.168.1.103")
    NAMES=("SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM")
    
    for i in "${!IPS[@]}"; do
        ip="${IPS[$i]}"
        name="${NAMES[$i]}"
        
        if ping -c 3 "$ip" &>/dev/null; then
            log_success "✅ $name ($ip) raggiungibile"
            
            # Test SSH
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               devops@"$ip" 'echo "SSH OK"' &>/dev/null; then
                log_success "✅ $name SSH funzionante"
            else
                log_warning "⚠️  $name SSH non ancora pronto"
            fi
        else
            log_error "❌ $name ($ip) non raggiungibile"
        fi
    done
}

verify_kubernetes_cluster() {
    log_info "Verifica cluster Kubernetes..."
    
    # Copy kubectl config from master
    log_info "Configurazione kubectl locale..."
    
    scp -o StrictHostKeyChecking=no \
        devops@192.168.1.101:~/.kube/config \
        ~/.kube/config-crm-cluster 2>/dev/null || true
    
    if [ -f ~/.kube/config-crm-cluster ]; then
        export KUBECONFIG=~/.kube/config-crm-cluster
        
        # Test cluster connectivity
        if kubectl get nodes &>/dev/null; then
            log_success "✅ Cluster Kubernetes funzionante"
            
            echo ""
            echo "📊 CLUSTER STATUS:"
            kubectl get nodes -o wide
            echo ""
            echo "🔧 SYSTEM PODS:"
            kubectl get pods --all-namespaces | head -10
        else
            log_warning "⚠️  Cluster non ancora completamente pronto"
        fi
    else
        log_warning "⚠️  Config kubectl non disponibile"
    fi
}

# =============================================================================
# MONITORING AND LOGS
# =============================================================================

show_deployment_progress() {
    log_info "Monitoraggio progresso deployment..."
    
    # Show real-time logs during deployment
    tail -f "$LOG_FILE" &
    TAIL_PID=$!
    
    # Monitor VM creation
    local timeout=2700  # 45 minutes
    local elapsed=0
    local interval=60   # Check every minute
    
    while [ $elapsed -lt $timeout ]; do
        if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
            # Check if all VMs are created
            local created_vms=$(cd "$TERRAFORM_DIR" && terraform show | grep -c "null_resource.create_vms" || echo 0)
            if [ "$created_vms" -eq 3 ]; then
                log_info "Tutte le VM sono state create"
                break
            fi
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        log_info "Deployment in corso... ($((elapsed / 60)) minuti trascorsi)"
    done
    
    # Stop log monitoring
    kill $TAIL_PID 2>/dev/null || true
}

# =============================================================================
# RESULTS AND NEXT STEPS
# =============================================================================

show_deployment_results() {
    echo ""
    log_success "🎉 DEPLOYMENT INFRASTRUTTURA COMPLETATO!"
    echo ""
    echo -e "${GREEN}📊 INFRASTRUTTURA CREATA:${NC}"
    echo ""
    echo "   🖥️  VM VMware:"
    echo "      • SPESE_FE_VM: 192.168.1.101 (Master + Frontend)"
    echo "      • SPESE_BE_VM: 192.168.1.102 (Worker + Backend)"
    echo "      • SPESE_DB_VM: 192.168.1.103 (Worker + Database)"
    echo ""
    echo "   ☸️  Kubernetes Cluster:"
    echo "      • Master: 192.168.1.101"
    echo "      • Workers: 192.168.1.102, 192.168.1.103"
    echo "      • CNI: Flannel"
    echo "      • Load Balancer: MetalLB (192.168.1.200-220)"
    echo ""
    echo -e "${BLUE}🔌 ACCESS INFO:${NC}"
    echo ""
    echo "   SSH alle VM:"
    echo "      ssh devops@192.168.1.101  # Master"
    echo "      ssh devops@192.168.1.102  # Backend Worker"
    echo "      ssh devops@192.168.1.103  # Database Worker"
    echo ""
    echo "   Kubectl config:"
    echo "      export KUBECONFIG=~/.kube/config-crm-cluster"
    echo "      kubectl get nodes"
    echo ""
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
    echo ""
    echo "   1. Test infrastruttura:"
    echo "      ./test_infrastructure.sh"
    echo ""
    echo "   2. Deploy applicazione CRM:"
    echo "      ./deploy_application.sh"
    echo ""
    echo "   3. Test applicazione:"
    echo "      ./test_application.sh"
    echo ""
    echo -e "${GREEN}✅ Infrastructure as Code deployment completato!${NC}"
    echo ""
}

save_deployment_info() {
    log_info "Salvataggio informazioni deployment..."
    
    cat > "$SCRIPT_DIR/deployment-info.txt" << EOF
# DEPLOYMENT INFO - FASE 7
# Generated: $(date)

## VM Details
SPESE_FE_VM: 192.168.1.101 (Master + Frontend)
SPESE_BE_VM: 192.168.1.102 (Worker + Backend)  
SPESE_DB_VM: 192.168.1.103 (Worker + Database)

## Access Commands
SSH_FE: ssh devops@192.168.1.101
SSH_BE: ssh devops@192.168.1.102
SSH_DB: ssh devops@192.168.1.103

## Kubernetes Config
KUBECONFIG: ~/.kube/config-crm-cluster
MASTER_IP: 192.168.1.101
API_SERVER: https://192.168.1.101:6443

## Load Balancer Range
METALLB_POOL: 192.168.1.200-192.168.1.220

## Next Steps
1. ./test_infrastructure.sh
2. ./deploy_application.sh
3. ./test_application.sh
EOF
    
    log_success "Informazioni salvate in: deployment-info.txt"
}

# =============================================================================
# CLEANUP AND ERROR HANDLING
# =============================================================================

cleanup_on_error() {
    log_error "Errore durante il deployment"
    
    read -p "Vuoi fare cleanup delle risorse parzialmente create? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup in corso..."
        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve || true
    fi
}

# Error handling
trap cleanup_on_error ERR

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    print_header
    
    log_info "Avvio deployment infrastruttura Fase 7..."
    
    # Step 1: Prerequisites
    check_prerequisites
    check_network_availability
    
    # Step 2: Terraform preparation
    prepare_terraform
    terraform_plan
    
    # Step 3: Infrastructure deployment
    terraform_apply
    
    # Step 4: Verification
    verify_vm_creation
    sleep 60  # Wait for VMs to fully start
    verify_vm_connectivity
    sleep 120  # Wait for Kubernetes to initialize
    verify_kubernetes_cluster
    
    # Step 5: Results
    save_deployment_info
    show_deployment_results
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
