#!/bin/bash

# =============================================================================
# PREREQUISITES CHECKER - FASE 7
# =============================================================================
# Verifica e installa dipendenze necessarie per Infrastructure as Code
# =============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
MIN_DOCKER_VERSION="20.10"
MIN_TERRAFORM_VERSION="1.0"
MIN_VMWARE_VERSION="15.0"

# Funzioni di utility
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

print_header() {
    echo ""
    echo "=============================================="
    echo "  PREREQUISITES CHECKER - FASE 7"
    echo "  Infrastructure as Code Dependencies"
    echo "=============================================="
    echo ""
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

check_system_resources() {
    log_info "Controllo risorse sistema..."
    
    # Check RAM disponibile (minimo 16GB per 3 VM da 4GB)
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    REQUIRED_RAM=16
    
    if [ "$TOTAL_RAM" -lt "$REQUIRED_RAM" ]; then
        log_warning "RAM disponibile: ${TOTAL_RAM}GB (minimo raccomandato: ${REQUIRED_RAM}GB)"
        log_warning "Le 3 VM potrebbero avere performance ridotte"
    else
        log_success "RAM disponibile: ${TOTAL_RAM}GB ✅"
    fi
    
    # Check CPU cores (minimo 4 cores per 3 VM da 2 core)
    CPU_CORES=$(nproc)
    REQUIRED_CORES=4
    
    if [ "$CPU_CORES" -lt "$REQUIRED_CORES" ]; then
        log_warning "CPU cores: $CPU_CORES (minimo raccomandato: $REQUIRED_CORES)"
    else
        log_success "CPU cores: $CPU_CORES ✅"
    fi
    
    # Check spazio disco (minimo 100GB per 3 VM da 25GB + overhead)
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    REQUIRED_SPACE=100
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warning "Spazio disco: ${AVAILABLE_SPACE}GB (minimo raccomandato: ${REQUIRED_SPACE}GB)"
    else
        log_success "Spazio disco: ${AVAILABLE_SPACE}GB ✅"
    fi
}

check_network_config() {
    log_info "Controllo configurazione network..."
    
    # Check network bridge per VMware
    if ip link show virbr0 &>/dev/null || ip link show vmnet1 &>/dev/null; then
        log_success "Network bridge disponibile ✅"
    else
        log_warning "Network bridge VMware non rilevato"
        log_info "Verrà configurato automaticamente con VMware"
    fi
    
    # Check range IP disponibili
    log_info "Verifica range IP 192.168.1.101-103..."
    for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            log_warning "IP $ip già in uso"
        else
            log_success "IP $ip disponibile ✅"
        fi
    done
}

# =============================================================================
# SOFTWARE CHECKS AND INSTALLATION
# =============================================================================

check_and_install_docker() {
    log_info "Controllo Docker..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        log_success "Docker $DOCKER_VERSION installato ✅"
        
        # Check Docker service
        if systemctl is-active --quiet docker; then
            log_success "Docker service attivo ✅"
        else
            log_warning "Docker service non attivo, avvio..."
            sudo systemctl start docker
            sudo systemctl enable docker
        fi
        
        # Check user in docker group
        if groups $USER | grep -q docker; then
            log_success "User in docker group ✅"
        else
            log_warning "User non in docker group, aggiunta..."
            sudo usermod -aG docker $USER
            log_warning "Riavvia la sessione per applicare le modifiche"
        fi
    else
        log_warning "Docker non installato, installazione..."
        install_docker
    fi
}

install_docker() {
    log_info "Installazione Docker..."
    
    # Update package index
    sudo apt-get update
    
    # Install dependencies
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installato ✅"
}

check_and_install_terraform() {
    log_info "Controllo Terraform..."
    
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        log_success "Terraform $TERRAFORM_VERSION installato ✅"
    else
        log_warning "Terraform non installato, installazione..."
        install_terraform
    fi
}

install_terraform() {
    log_info "Installazione Terraform..."
    
    # Download Terraform
    TERRAFORM_VERSION="1.6.6"
    cd /tmp
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    
    # Install unzip if not present
    sudo apt-get install -y unzip
    
    # Extract and install
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    
    # Verify installation
    terraform version
    
    log_success "Terraform installato ✅"
}

check_and_install_vmware() {
    log_info "Controllo VMware Workstation..."
    
    if command -v vmware &> /dev/null || command -v vmrun &> /dev/null; then
        log_success "VMware Workstation rilevato ✅"
        
        # Check vmrun specifically
        if command -v vmrun &> /dev/null; then
            VMWARE_VERSION=$(vmrun | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "Unknown")
            log_success "vmrun disponibile (versione: $VMWARE_VERSION) ✅"
        else
            log_warning "vmrun non trovato nel PATH"
            log_info "Verifica installazione VMware Workstation Pro"
        fi
    else
        log_error "VMware Workstation non installato!"
        log_info "Installa VMware Workstation Pro da:"
        log_info "https://www.vmware.com/products/workstation-pro.html"
        log_info ""
        log_info "Dopo l'installazione, riavvia questo script"
        exit 1
    fi
}

check_and_install_kubectl() {
    log_info "Controllo kubectl..."
    
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo "Unknown")
        log_success "kubectl $KUBECTL_VERSION installato ✅"
    else
        log_warning "kubectl non installato, installazione..."
        install_kubectl
    fi
}

install_kubectl() {
    log_info "Installazione kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Verify installation
    kubectl version --client
    
    log_success "kubectl installato ✅"
}

check_and_install_helm() {
    log_info "Controllo Helm..."
    
    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short | grep -oE '[0-9]+\.[0-9]+' || echo "Unknown")
        log_success "Helm $HELM_VERSION installato ✅"
    else
        log_warning "Helm non installato, installazione..."
        install_helm
    fi
}

install_helm() {
    log_info "Installazione Helm..."
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm installato ✅"
}

check_jenkins() {
    log_info "Controllo Jenkins..."
    
    if systemctl is-active --quiet jenkins; then
        log_success "Jenkins service attivo ✅"
        
        JENKINS_PORT=$(netstat -tlnp 2>/dev/null | grep java | grep :8080 | wc -l)
        if [ "$JENKINS_PORT" -gt 0 ]; then
            log_success "Jenkins UI accessibile su :8080 ✅"
        else
            log_warning "Jenkins potrebbe non essere accessibile su porta 8080"
        fi
    else
        log_warning "Jenkins service non attivo"
        log_info "Avvia Jenkins con: sudo systemctl start jenkins"
    fi
}

# =============================================================================
# TERRAFORM PROVIDER SETUP
# =============================================================================

setup_terraform_providers() {
    log_info "Setup Terraform providers..."
    
    # Crea directory terraform se non esiste
    TERRAFORM_DIR="$(dirname "$0")/terraform"
    mkdir -p "$TERRAFORM_DIR"
    
    # Crea file providers se non esiste
    if [ ! -f "$TERRAFORM_DIR/providers.tf" ]; then
        cat > "$TERRAFORM_DIR/providers.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

provider "local" {}
provider "null" {}
EOF
        log_success "Terraform providers.tf creato ✅"
    fi
    
    # Initialize Terraform
    cd "$TERRAFORM_DIR"
    terraform init
    log_success "Terraform inizializzato ✅"
}

# =============================================================================
# VALIDATION AND SUMMARY
# =============================================================================

validate_installation() {
    log_info "Validazione installazione finale..."
    
    # Test Docker
    if docker run --rm hello-world &>/dev/null; then
        log_success "Docker funzionale ✅"
    else
        log_warning "Docker test fallito"
    fi
    
    # Test Terraform
    if terraform version &>/dev/null; then
        log_success "Terraform funzionale ✅"
    else
        log_warning "Terraform test fallito"
    fi
    
    # Test kubectl
    if kubectl version --client &>/dev/null; then
        log_success "kubectl funzionale ✅"
    else
        log_warning "kubectl test fallito"
    fi
}

show_summary() {
    echo ""
    log_success "🎉 PREREQUISITES CHECK COMPLETATO!"
    echo ""
    echo -e "${GREEN}✅ SOFTWARE INSTALLATO:${NC}"
    echo "   - Docker: $(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'Non installato')"
    echo "   - Terraform: $(terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 'Non installato')"
    echo "   - kubectl: $(kubectl version --client 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'Non installato')"
    echo "   - Helm: $(helm version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'Non installato')"
    echo ""
    echo -e "${BLUE}🚀 NEXT STEPS:${NC}"
    echo "   1. ./deploy_infrastructure.sh - Crea 3 VM VMware"
    echo "   2. ./test_infrastructure.sh - Testa infrastruttura"
    echo "   3. ./deploy_application.sh - Deploy CRM su cluster"
    echo ""
    
    if groups $USER | grep -q docker; then
        echo -e "${GREEN}✅ Pronto per il deployment!${NC}"
    else
        echo -e "${YELLOW}⚠️  RIAVVIA LA SESSIONE per applicare docker group${NC}"
        echo "   Esegui: logout && login"
    fi
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    print_header
    
    log_info "Avvio controllo prerequisites per Fase 7..."
    
    # System checks
    check_system_resources
    check_network_config
    
    # Software installation
    check_and_install_docker
    check_and_install_terraform
    check_and_install_vmware
    check_and_install_kubectl
    check_and_install_helm
    check_jenkins
    
    # Setup
    setup_terraform_providers
    
    # Final validation
    validate_installation
    show_summary
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
