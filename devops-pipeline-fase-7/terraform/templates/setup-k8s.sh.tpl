#!/bin/bash

# =============================================================================
# KUBERNETES SETUP SCRIPT TEMPLATE - TERRAFORM GENERATED
# =============================================================================
# VM: ${vm_name}
# Role: ${vm_role}
# IP: ${ip_address}
# =============================================================================

set -e

# Configuration
VM_NAME="${vm_name}"
VM_ROLE="${vm_role}"
IP_ADDRESS="${ip_address}"
IS_MASTER=${is_master}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "$${BLUE}[INFO]$${NC} $1"
}

log_success() {
    echo -e "$${GREEN}[SUCCESS]$${NC} $1"
}

log_warning() {
    echo -e "$${YELLOW}[WARNING]$${NC} $1"
}

log_error() {
    echo -e "$${RED}[ERROR]$${NC} $1"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

wait_for_vm_ready() {
    log_info "Waiting for VM $VM_NAME to be ready..."
    
    local timeout=300  # 5 minutes
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
           devops@"$IP_ADDRESS" 'echo "VM ready"' >/dev/null 2>&1; then
            log_success "VM $VM_NAME is ready"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        log_info "Waiting... ($elapsed/$timeout seconds)"
    done
    
    log_error "VM $VM_NAME not ready after $timeout seconds"
    return 1
}

verify_kubernetes_prerequisites() {
    log_info "Verifying Kubernetes prerequisites on $VM_NAME..."
    
    ssh -o StrictHostKeyChecking=no devops@"$IP_ADDRESS" '
        echo "Checking Docker..."
        if ! docker --version >/dev/null 2>&1; then
            echo "ERROR: Docker not installed or not working"
            exit 1
        fi
        
        echo "Checking kubelet..."
        if ! which kubelet >/dev/null 2>&1; then
            echo "ERROR: kubelet not installed"
            exit 1
        fi
        
        echo "Checking kubeadm..."
        if ! which kubeadm >/dev/null 2>&1; then
            echo "ERROR: kubeadm not installed"
            exit 1
        fi
        
        echo "Checking kubectl..."
        if ! which kubectl >/dev/null 2>&1; then
            echo "ERROR: kubectl not installed"
            exit 1
        fi
        
        echo "Checking swap is disabled..."
        if [ $(swapon --show | wc -l) -gt 0 ]; then
            echo "ERROR: Swap is still enabled"
            exit 1
        fi
        
        echo "All prerequisites verified!"
    '
    
    log_success "Prerequisites verified on $VM_NAME"
}

%{ if is_master }
setup_master_node() {
    log_info "Setting up Kubernetes master node..."
    
    ssh -o StrictHostKeyChecking=no devops@"$IP_ADDRESS" '
        echo "Initializing Kubernetes master..."
        
        # Initialize cluster
        sudo kubeadm init \
            --pod-network-cidr=10.244.0.0/16 \
            --apiserver-advertise-address=${ip_address} \
            --node-name=${vm_name}
        
        # Setup kubectl for devops user
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Install Flannel CNI
        echo "Installing Flannel CNI..."
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
        
        # Wait for master node to be ready
        echo "Waiting for master node to be ready..."
        while ! kubectl get nodes | grep -q "Ready"; do
            echo "Master node not ready yet, waiting..."
            sleep 10
        done
        
        # Generate join token for workers
        echo "Generating join token for worker nodes..."
        kubeadm token create --print-join-command > /tmp/k8s-join-command
        
        # Install Nginx Ingress Controller
        echo "Installing Nginx Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
        
        # Install MetalLB Load Balancer
        echo "Installing MetalLB..."
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
        
        # Wait for MetalLB to be ready
        kubectl wait --namespace metallb-system \
            --for=condition=ready pod \
            --selector=app=metallb \
            --timeout=90s
        
        # Configure MetalLB address pool
        cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: crm-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.220
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: crm-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - crm-pool
EOF
        
        echo "Master node setup completed!"
        kubectl get nodes
        kubectl get pods --all-namespaces
    '
    
    # Copy join command to local machine
    scp -o StrictHostKeyChecking=no devops@"$IP_ADDRESS":/tmp/k8s-join-command ./k8s-join-command
    
    log_success "Master node setup completed"
}
%{ else }
setup_worker_node() {
    log_info "Setting up Kubernetes worker node..."
    
    # Wait for join command to be available
    while [ ! -f "./k8s-join-command" ]; do
        log_info "Waiting for join command from master..."
        sleep 10
    done
    
    # Read join command
    JOIN_COMMAND=$(cat ./k8s-join-command)
    
    ssh -o StrictHostKeyChecking=no devops@"$IP_ADDRESS" "
        echo 'Joining worker node to cluster...'
        sudo $JOIN_COMMAND --node-name=${vm_name}
        
        echo 'Worker node joined successfully!'
    "
    
    log_success "Worker node setup completed"
}
%{ endif }

configure_node_labels() {
    log_info "Configuring node labels and taints..."
    
    # Configure from master node
    ssh -o StrictHostKeyChecking=no devops@192.168.1.101 "
        # Wait for node to appear in cluster
        while ! kubectl get node ${vm_name} >/dev/null 2>&1; do
            echo 'Waiting for node ${vm_name} to appear in cluster...'
            sleep 5
        done
        
        # Add role-specific labels
        kubectl label node ${vm_name} node-role.kubernetes.io/${vm_role}=true --overwrite
        kubectl label node ${vm_name} crm.component=${vm_role} --overwrite
        
        %{ if vm_role == "master" }
        # Master node configuration
        kubectl label node ${vm_name} crm.services=frontend,ingress --overwrite
        %{ endif }
        
        %{ if vm_role == "worker" && ip_address == "192.168.1.102" }
        # Backend worker configuration  
        kubectl label node ${vm_name} crm.services=backend,api --overwrite
        %{ endif }
        
        %{ if vm_role == "worker" && ip_address == "192.168.1.103" }
        # Database worker configuration
        kubectl label node ${vm_name} crm.services=database,storage --overwrite
        %{ endif }
        
        echo 'Node labels configured successfully!'
        kubectl get nodes --show-labels
    "
    
    log_success "Node labels configured"
}

verify_cluster_connectivity() {
    log_info "Verifying cluster connectivity..."
    
    ssh -o StrictHostKeyChecking=no devops@192.168.1.101 "
        echo 'Cluster Status:'
        kubectl get nodes -o wide
        
        echo ''
        echo 'System Pods:'
        kubectl get pods --all-namespaces | grep -E '(kube-system|metallb|ingress)'
        
        echo ''
        echo 'Cluster Info:'
        kubectl cluster-info
    "
    
    log_success "Cluster connectivity verified"
}

show_node_info() {
    echo ""
    log_success "🎉 KUBERNETES NODE $VM_NAME READY!"
    echo ""
    echo -e "$${GREEN}📊 Node Details:$${NC}"
    echo "   Name: $VM_NAME"
    echo "   Role: $VM_ROLE"
    echo "   IP Address: $IP_ADDRESS"
    echo ""
    echo -e "$${BLUE}🔌 Access Info:$${NC}"
    echo "   SSH: ssh devops@$IP_ADDRESS"
    %{ if is_master }
    echo "   Kubectl: Copy config from devops@$IP_ADDRESS:~/.kube/config"
    echo "   API Server: https://$IP_ADDRESS:6443"
    %{ endif }
    echo ""
    echo -e "$${YELLOW}📋 Next Steps:$${NC}"
    %{ if is_master }
    echo "   1. Verify cluster: kubectl get nodes"
    echo "   2. Wait for worker nodes to join"
    echo "   3. Deploy CRM application"
    %{ else }
    echo "   1. Node should be visible in: kubectl get nodes"
    echo "   2. Check node status from master"
    %{ endif }
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🔧 Setting up Kubernetes on $VM_NAME ($VM_ROLE)"
    echo ""
    
    # Step 1: Wait for VM
    wait_for_vm_ready
    
    # Step 2: Verify prerequisites
    verify_kubernetes_prerequisites
    
    # Step 3: Setup node based on role
    %{ if is_master }
    setup_master_node
    %{ else }
    setup_worker_node
    %{ endif }
    
    # Step 4: Configure labels
    configure_node_labels
    
    # Step 5: Verify connectivity
    verify_cluster_connectivity
    
    # Step 6: Show results
    show_node_info
}

# Execute main function
main "$@"
