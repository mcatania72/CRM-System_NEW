#!/bin/bash

# =============================================================================
# VM CLONE SCRIPT - SIMPLIFIED TEMPLATE APPROACH
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
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"
USERNAME="${vm_credentials_username}"

# Paths
TEMPLATE_DIR="$HOME/VMware_VMs/ubuntu-cloud-template"
VM_DIR="$HOME/VMware_VMs/$VM_NAME"
VMX_FILE="$VM_DIR/$VM_NAME.vmx"

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
    
    # Check template exists
    TEMPLATE_VMX=$(find "$TEMPLATE_DIR" -name "*.vmx" | head -1)
    if [ -z "$TEMPLATE_VMX" ]; then
        log_error "Template not found in $TEMPLATE_DIR"
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

clone_vm_from_template() {
    log_info "Cloning VM from template..."
    
    # Find template VMX
    TEMPLATE_VMX=$(find "$TEMPLATE_DIR" -name "*.vmx" | head -1)
    TEMPLATE_BASE_DIR=$(dirname "$TEMPLATE_VMX")
    
    log_info "Template found: $TEMPLATE_VMX"
    
    # Create VM directory
    mkdir -p "$VM_DIR"
    
    # Clone all files from template
    cp -r "$TEMPLATE_BASE_DIR"/* "$VM_DIR/"
    
    # Find and rename VMX file
    ORIGINAL_VMX=$(find "$VM_DIR" -name "*.vmx" | head -1)
    if [ -f "$ORIGINAL_VMX" ]; then
        mv "$ORIGINAL_VMX" "$VMX_FILE"
        log_info "VMX renamed to: $VM_NAME.vmx"
    else
        log_error "No VMX file found after clone"
        exit 1
    fi
    
    # Rename VMDK file
    ORIGINAL_VMDK=$(find "$VM_DIR" -name "*.vmdk" | head -1)
    if [ -f "$ORIGINAL_VMDK" ]; then
        NEW_VMDK="$VM_DIR/$VM_NAME.vmdk"
        mv "$ORIGINAL_VMDK" "$NEW_VMDK"
        log_info "VMDK renamed to: $VM_NAME.vmdk"
    fi
    
    log_success "VM cloned successfully"
}

customize_vm_configuration() {
    log_info "Customizing VM configuration..."
    
    # Create custom VMX configuration
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

# Cloud-init guestinfo injection
guestinfo.metadata = "$(echo "instance-id: $VM_NAME-$(date +%s)\nlocal-hostname: $VM_NAME" | base64 -w 0)"
guestinfo.metadata.encoding = "base64"
guestinfo.userdata = "$(cat << 'USERDATA_EOF' | base64 -w 0
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true

users:
  - name: $USERNAME
    passwd: \$6\$rounds=4096\$saltsalt\$3qg8hkTVt8.yt/j5MqC8LG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm/Kf8F3nOSv8x8h9v8h9v8h9v8h9v8h
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash

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

package_update: true
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - docker.io
  - apt-transport-https
  - ca-certificates
  - gnupg

runcmd:
  - netplan apply
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker $USERNAME
  - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  - echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab
  - modprobe br_netfilter
  - echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
  - sysctl --system

ssh_pwauth: true
disable_root: false

final_message: "🎉 $VM_NAME ready! IP: $IP_ADDRESS"
USERDATA_EOF
)"
guestinfo.userdata.encoding = "base64"
EOF

    log_success "VM configuration customized"
}

start_vm() {
    log_info "Starting VM $VM_NAME..."
    
    vmrun -T ws start "$VMX_FILE"
    
    log_success "VM started"
    log_info "Cloud-init will configure the system automatically"
}

wait_for_vm() {
    log_info "Waiting for VM to be ready..."
    
    TIMEOUT=600  # 10 minutes
    ELAPSED=0
    INTERVAL=15
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if ping -c 1 "$IP_ADDRESS" >/dev/null 2>&1; then
            log_info "VM is responding to ping"
            
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               $USERNAME@"$IP_ADDRESS" 'echo "SSH ready"' >/dev/null 2>&1; then
                log_success "VM is ready and accessible!"
                return 0
            fi
        fi
        
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        log_info "Progress: $((ELAPSED / 60)) minutes elapsed..."
    done
    
    log_error "VM readiness timeout"
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
    echo "   Memory: $${MEMORY_MB}MB"
    echo "   CPU Cores: $NUM_CPUS"
    echo ""
    echo -e "$${BLUE}🔌 Access Info:$${NC}"
    echo "   SSH: ssh $USERNAME@$IP_ADDRESS"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🚀 Creating VM from template: $VM_NAME"
    echo ""
    
    check_prerequisites
    clone_vm_from_template
    customize_vm_configuration
    start_vm
    wait_for_vm
    show_vm_info
}

# Execute main function
main "$@"
