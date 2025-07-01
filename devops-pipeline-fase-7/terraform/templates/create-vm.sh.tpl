#!/bin/bash

# =============================================================================
# VM CREATION SCRIPT TEMPLATE - OVA IMPORT APPROACH
# =============================================================================
# Creates VMware VM: ${vm_name}
# Role: ${vm_role}
# IP: ${ip_address}
# =============================================================================

set -e

# VM Configuration
VM_NAME="${vm_name}"
VM_DESCRIPTION="${vm_description}"
MEMORY_MB="${memory_mb}"
NUM_CPUS="${num_cpus}"
DISK_SIZE_MB="${disk_size_mb}"
OVA_PATH="/home/devops/images/jammy-server-cloudimg-amd64.ova"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"

# Paths
VM_DIR="$HOME/VMware_VMs/$VM_NAME"
VMX_FILE="$VM_DIR/$VM_NAME.vmx"
TEMPLATE_DIR="$HOME/VMware_VMs/ubuntu-cloud-template"
TEMPLATE_VMX="$TEMPLATE_DIR/jammy-server-cloudimg-amd64.vmx"

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

check_prerequisites() {
    log_info "Checking prerequisites for $VM_NAME..."
    
    # Check vmrun
    if ! command -v vmrun &> /dev/null; then
        log_error "vmrun not found! Install VMware Workstation"
        exit 1
    fi
    
    # Check ovftool
    if ! command -v ovftool &> /dev/null; then
        log_error "ovftool not found! Install VMware OVF Tool"
        exit 1
    fi
    
    # Check OVA file
    if [ ! -f "$OVA_PATH" ]; then
        log_error "Ubuntu Cloud OVA not found: $OVA_PATH"
        exit 1
    fi
    
    # Check if VM already exists and remove automatically
    if [ -d "$VM_DIR" ]; then
        log_warning "VM directory already exists: $VM_DIR"
        log_info "Removing existing VM automatically..."
        vmrun stop "$VMX_FILE" 2>/dev/null || true
        vmrun deleteVM "$VMX_FILE" 2>/dev/null || true
        rm -rf "$VM_DIR"
        log_success "Existing VM removed"
    fi
    
    log_success "Prerequisites OK"
}

import_ova_template() {
    log_info "Setting up Ubuntu Cloud template..."
    
    # Create template directory if not exists
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_info "Importing OVA template..."
        mkdir -p "$TEMPLATE_DIR"
        
        # Import OVA to template directory
        ovftool --acceptAllEulas --allowExtraConfig \
            --name="jammy-server-cloudimg-amd64" \
            "$OVA_PATH" "$TEMPLATE_DIR/"
        
        log_success "OVA template imported"
    else
        log_info "Template already exists, skipping import"
    fi
}

clone_vm_from_template() {
    log_info "Cloning VM from template..."
    
    # Create VM directory
    mkdir -p "$VM_DIR"
    
    # Clone all files from template
    cp -r "$TEMPLATE_DIR"/* "$VM_DIR/"
    
    # Rename VMX file
    mv "$VM_DIR/jammy-server-cloudimg-amd64.vmx" "$VMX_FILE"
    
    # Rename VMDK files to match VM name
    for vmdk in "$VM_DIR"/*.vmdk; do
        if [ -f "$vmdk" ]; then
            base_name=$(basename "$vmdk")
            new_name=$(echo "$base_name" | sed "s/jammy-server-cloudimg-amd64/$VM_NAME/g")
            mv "$vmdk" "$VM_DIR/$new_name"
        fi
    done
    
    log_success "VM cloned from template"
}

customize_vm_configuration() {
    log_info "Customizing VM configuration..."
    
    # Update VMX file with new settings
    cat > "$VMX_FILE" << EOF
#!/usr/bin/vmware
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"

# VM Identification
displayName = "$VM_NAME"
annotation = "$VM_DESCRIPTION|0A|Role: $VM_ROLE|0A|IP: $IP_ADDRESS"

# Hardware Configuration
memsize = "$MEMORY_MB"
numvcpus = "$NUM_CPUS"
cpuid.coresPerSocket = "1"

# Disk Configuration
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$VM_NAME.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"

# Network Configuration
ethernet0.present = "TRUE"
ethernet0.connectionType = "bridged"
ethernet0.virtualDev = "e1000"
ethernet0.wakeOnPcktRcv = "FALSE"
ethernet0.addressType = "generated"

# USB Configuration
usb.present = "TRUE"
ehci.present = "TRUE"
ehci.pciSlotNumber = "35"

# Sound Configuration
sound.present = "TRUE"
sound.fileName = "-1"
sound.autodetect = "TRUE"

# Other Settings
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"

vmci0.present = "TRUE"
hpet0.present = "TRUE"
guestOS = "ubuntu-64"

# Tools
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"

# Power Options
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"

# Cloud-init configuration
guestinfo.metadata = "$(base64 -w 0 "$VM_DIR/meta-data" 2>/dev/null || echo "")"
guestinfo.metadata.encoding = "base64"
guestinfo.userdata = "$(base64 -w 0 "$VM_DIR/user-data" 2>/dev/null || echo "")"  
guestinfo.userdata.encoding = "base64"
EOF

    log_success "VM configuration customized"
}

create_cloud_init_config() {
    log_info "Creating cloud-init configuration..."
    
    # Create meta-data
    cat > "$VM_DIR/meta-data" << EOF
instance-id: $VM_NAME-$(date +%s)
local-hostname: $VM_NAME
EOF

    # Create user-data with network configuration
    cat > "$VM_DIR/user-data" << EOF
#cloud-config

# System configuration
hostname: $VM_NAME
manage_etc_hosts: true

# User configuration
users:
  - name: ${vm_credentials_username}
    passwd: \$6\$rounds=4096\$saltsalt\$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm/Kf8F3nOSv8x8h9v8h9v8h9v8h9v8h9v8h  # devops123
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: []

# Network configuration
write_files:
  - path: /etc/netplan/00-installer-config.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens33:
            dhcp4: false
            addresses:
              - $IP_ADDRESS/24
            gateway4: ${gateway}
            nameservers:
              addresses: ${jsonencode(dns_servers)}
    permissions: '0600'

# Package updates and installations
package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - software-properties-common
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release

# Commands to run
runcmd:
  # Apply network configuration
  - netplan apply
  
  # Install Docker
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - usermod -aG docker ${vm_credentials_username}
  - systemctl enable docker
  - systemctl start docker
  
  # Install Kubernetes tools
  - curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  
  # System optimization for Kubernetes
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab
  - modprobe br_netfilter
  - echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
  - echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
  - sysctl --system

# SSH configuration
ssh_pwauth: true
disable_root: false

# Final message
final_message: |
  ====================================
  🎉 $VM_NAME READY!
  ====================================
  
  VM Role: $VM_ROLE  
  IP Address: $IP_ADDRESS
  Username: ${vm_credentials_username}
  
  SSH Access: ssh ${vm_credentials_username}@$IP_ADDRESS
  
  Ready for Kubernetes cluster setup!
  ====================================
EOF

    log_success "Cloud-init configuration created"
}

start_vm() {
    log_info "Starting VM $VM_NAME..."
    
    # Start VM
    vmrun -T ws start "$VMX_FILE"
    
    log_success "VM started"
    log_info "Cloud-init will configure the system automatically"
    log_info "This process takes about 3-5 minutes"
}

wait_for_cloud_init() {
    log_info "Waiting for cloud-init to complete..."
    
    # Wait for VM to be responsive on SSH
    TIMEOUT=600  # 10 minutes
    ELAPSED=0
    INTERVAL=15
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if ping -c 1 "$IP_ADDRESS" >/dev/null 2>&1; then
            log_info "VM is responding to ping"
            
            # Try SSH connection
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               ${vm_credentials_username}@"$IP_ADDRESS" 'echo "SSH ready"' >/dev/null 2>&1; then
                log_success "Cloud-init completed! VM is ready"
                log_success "VM accessible at $IP_ADDRESS"
                return 0
            fi
        fi
        
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        log_info "Cloud-init progress: $((ELAPSED / 60)) minutes elapsed..."
    done
    
    log_error "Cloud-init timeout reached"
    return 1
}

show_vm_info() {
    echo ""
    log_success "🎉 VM $VM_NAME CREATED SUCCESSFULLY!"
    echo ""
    echo -e "$${GREEN}📊 VM Details:$${NC}"
    echo "   Name: $VM_NAME"
    echo "   Role: $VM_ROLE"
    echo "   IP Address: $IP_ADDRESS"
    echo "   Memory: $${MEMORY_MB}MB ($((MEMORY_MB / 1024))GB)"
    echo "   CPU Cores: $NUM_CPUS"
    echo "   Disk: $${DISK_SIZE_MB}MB ($((DISK_SIZE_MB / 1024))GB)"
    echo ""
    echo -e "$${BLUE}🔌 Access Info:$${NC}"
    echo "   SSH: ssh ${vm_credentials_username}@$IP_ADDRESS"
    echo "   VMX File: $VMX_FILE"
    echo ""
    echo -e "$${YELLOW}📋 Next Steps:$${NC}"
    echo "   1. Verify VM connectivity"
    echo "   2. Setup Kubernetes on this node"
    echo "   3. Join to cluster (if worker)"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🚀 Creating VMware VM from Ubuntu Cloud OVA: $VM_NAME"
    echo ""
    
    # Debug info
    echo "Debug info:"
    echo "  VM_NAME: $VM_NAME"
    echo "  MEMORY_MB: $MEMORY_MB"
    echo "  NUM_CPUS: $NUM_CPUS"
    echo "  DISK_SIZE_MB: $DISK_SIZE_MB"
    echo "  OVA_PATH: $OVA_PATH"
    echo "  IP_ADDRESS: $IP_ADDRESS"
    echo ""
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Import OVA template (once)
    import_ova_template
    
    # Step 3: Clone VM from template
    clone_vm_from_template
    
    # Step 4: Customize VM configuration
    customize_vm_configuration
    
    # Step 5: Create cloud-init config
    create_cloud_init_config
    
    # Step 6: Start VM
    start_vm
    
    # Step 7: Wait for cloud-init
    wait_for_cloud_init
    
    # Step 8: Show results
    show_vm_info
}

# Execute main function
main "$@"
