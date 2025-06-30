#!/bin/bash

# FASE 6: Prerequisites per Kubernetes Deployment
# Verifica k3s e prepara environment per CRM deployment

set -e  # Exit on any error

# Colors per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="$HOME/prerequisites-k8s.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}=== 🎯 FASE 6: Prerequisites Kubernetes ===${NC}"
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""

# Check if running as devops user
if [ "$(whoami)" != "devops" ]; then
    echo -e "${YELLOW}⚠️  Warning: Running as $(whoami), expected 'devops'${NC}"
fi

# Function to check command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✅ $1 is installed${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 is not installed${NC}"
        return 1
    fi
}

# Function to check k3s service
check_k3s_service() {
    echo -e "${BLUE}🔍 Checking k3s service...${NC}"
    
    if systemctl is-active --quiet k3s; then
        echo -e "${GREEN}✅ k3s service is active${NC}"
        
        # Check k3s version
        K3S_VERSION=$(sudo k3s --version | head -n1)
        echo "   Version: $K3S_VERSION"
        
        # Check cluster status
        if sudo k3s kubectl get nodes &>/dev/null; then
            echo -e "${GREEN}✅ k3s cluster is responding${NC}"
            sudo k3s kubectl get nodes
        else
            echo -e "${RED}❌ k3s cluster is not responding${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ k3s service is not active${NC}"
        echo "   Status: $(systemctl is-active k3s 2>/dev/null || echo 'inactive')"
        return 1
    fi
}

# Function to check storage classes
check_storage() {
    echo -e "${BLUE}🔍 Checking storage classes...${NC}"
    
    if sudo k3s kubectl get storageclass &>/dev/null; then
        echo -e "${GREEN}✅ Storage classes available:${NC}"
        sudo k3s kubectl get storageclass
        
        # Check if local-path is default
        if sudo k3s kubectl get storageclass local-path -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null | grep -q "true"; then
            echo -e "${GREEN}✅ local-path is default storage class${NC}"
        else
            echo -e "${YELLOW}⚠️  local-path is not default storage class${NC}"
        fi
    else
        echo -e "${RED}❌ Cannot access storage classes${NC}"
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    echo -e "${BLUE}🔍 Checking network configuration...${NC}"
    
    # Check if Docker is running (k3s needs containerd but Docker might be used for builds)
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✅ Docker service is active${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker service is not active${NC}"
    fi
    
    # Check network interfaces
    echo "Network interfaces:"
    ip addr show | grep -E "inet.*global" | while read line; do
        echo "   $line"
    done
    
    # Check if Traefik LoadBalancer is working
    if sudo k3s kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q "192.168.1.29"; then
        echo -e "${GREEN}✅ Traefik LoadBalancer IP: 192.168.1.29${NC}"
    else
        echo -e "${YELLOW}⚠️  Traefik LoadBalancer IP not set to 192.168.1.29${NC}"
    fi
}

# Function to check existing workloads
check_existing_workloads() {
    echo -e "${BLUE}🔍 Checking existing workloads...${NC}"
    
    # Check if crm-system namespace already exists
    if sudo k3s kubectl get namespace crm-system &>/dev/null; then
        echo -e "${YELLOW}⚠️  crm-system namespace already exists${NC}"
        sudo k3s kubectl get all -n crm-system
    else
        echo -e "${GREEN}✅ crm-system namespace does not exist (clean state)${NC}"
    fi
    
    # Check port conflicts
    echo "Checking for port conflicts..."
    if sudo k3s kubectl get svc --all-namespaces -o wide | grep -E ":30002|:30003"; then
        echo -e "${YELLOW}⚠️  Potential port conflicts found:${NC}"
        sudo k3s kubectl get svc --all-namespaces -o wide | grep -E ":30002|:30003"
    else
        echo -e "${GREEN}✅ No port conflicts on 30002/30003${NC}"
    fi
}

# Function to check resources
check_resources() {
    echo -e "${BLUE}🔍 Checking system resources...${NC}"
    
    # Memory check
    MEM_TOTAL=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
    MEM_AVAILABLE=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    echo "Memory: ${MEM_AVAILABLE}GB available / ${MEM_TOTAL}GB total"
    
    if (( $(echo "$MEM_AVAILABLE > 8" | bc -l) )); then
        echo -e "${GREEN}✅ Sufficient memory for K8s deployment${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited memory (${MEM_AVAILABLE}GB), deployment might be constrained${NC}"
    fi
    
    # CPU check
    CPU_CORES=$(nproc)
    echo "CPU: $CPU_CORES cores"
    
    if [ "$CPU_CORES" -ge 2 ]; then
        echo -e "${GREEN}✅ Sufficient CPU cores${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited CPU cores, consider reducing replicas${NC}"
    fi
    
    # Disk check
    DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
    echo "Disk: $DISK_AVAILABLE available"
    
    if df -h / | awk 'NR==2 {print $4}' | grep -E "^[0-9]+G" | head -n1 | sed 's/G.*//' | awk '{if($1 >= 10) print "OK"}' | grep -q "OK"; then
        echo -e "${GREEN}✅ Sufficient disk space${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited disk space, monitor storage usage${NC}"
    fi
}

# Function to prepare kubeconfig
setup_kubeconfig() {
    echo -e "${BLUE}🔧 Setting up kubeconfig...${NC}"
    
    # Create .kube directory if it doesn't exist
    mkdir -p "$HOME/.kube"
    
    # Copy k3s config to standard location
    if sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config" 2>/dev/null; then
        sudo chown $(whoami):$(whoami) "$HOME/.kube/config"
        chmod 600 "$HOME/.kube/config"
        echo -e "${GREEN}✅ kubeconfig copied to ~/.kube/config${NC}"
        
        # Test kubectl access
        if kubectl get nodes &>/dev/null; then
            echo -e "${GREEN}✅ kubectl access confirmed${NC}"
        else
            echo -e "${YELLOW}⚠️  kubectl access issues, using 'sudo k3s kubectl' instead${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not copy kubeconfig, will use 'sudo k3s kubectl'${NC}"
    fi
}

# Function to install additional tools if needed
install_tools() {
    echo -e "${BLUE}🔧 Checking additional tools...${NC}"
    
    # Check kubectl (standalone)
    if ! check_command kubectl; then
        echo "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        echo -e "${GREEN}✅ kubectl installed${NC}"
    fi
    
    # Check helm (for future use)
    if ! check_command helm; then
        echo "Helm not found, but not required for FASE 6"
    fi
    
    # Check git
    check_command git || echo -e "${YELLOW}⚠️  Git recommended for code updates${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting prerequisites check...${NC}"
    
    ERRORS=0
    
    # Core checks
    check_k3s_service || ERRORS=$((ERRORS + 1))
    check_storage || ERRORS=$((ERRORS + 1))
    check_network
    check_existing_workloads
    check_resources
    
    # Setup
    setup_kubeconfig
    install_tools
    
    echo ""
    echo -e "${BLUE}=== 📊 SUMMARY ===${NC}"
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✅ All critical checks passed!${NC}"
        echo -e "${GREEN}🚀 Ready for FASE 6 Kubernetes deployment${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "1. Run: ./deploy-k8s.sh start"
        echo "2. Test: ./test-k8s.sh"
        echo "3. Access: http://192.168.1.29/crm"
    else
        echo -e "${RED}❌ $ERRORS critical issues found${NC}"
        echo -e "${YELLOW}Please fix issues before proceeding with deployment${NC}"
        exit 1
    fi
    
    echo ""
    echo "Log saved to: $LOG_FILE"
}

# Handle command line arguments
case "${1:-}" in
    --fix)
        echo -e "${BLUE}🔧 Attempting to fix common issues...${NC}"
        
        # Restart k3s if needed
        if ! systemctl is-active --quiet k3s; then
            echo "Restarting k3s..."
            sudo systemctl restart k3s
            sleep 10
        fi
        
        # Fix permissions
        setup_kubeconfig
        
        echo -e "${GREEN}✅ Fix attempt completed${NC}"
        ;;
    --help)
        echo "Usage: $0 [--fix|--help]"
        echo ""
        echo "Options:"
        echo "  --fix    Attempt to fix common issues"
        echo "  --help   Show this help message"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
