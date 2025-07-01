#!/bin/bash

# =============================================================================
# VM CREATION SCRIPT TEMPLATE - TERRAFORM GENERATED
# =============================================================================
# Creates VMware VM: ${vm_name}
# Role: ${vm_role}
# IP: ${ip_address}
# =============================================================================

set -e

# VM Configuration
VM_NAME="${vm_name}"
VM_DESCRIPTION="${vm_description}"
MEMORY_MB=${memory_mb}
NUM_CPUS=${num_cpus}
DISK_SIZE_MB=${disk_size_mb}
ISO_PATH="${iso_path}"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"

# Paths
VM_DIR="$HOME/VMware_VMs/$VM_NAME"
VMX_FILE="$VM_DIR/$VM_NAME.vmx"
VMDK_FILE="$VM_DIR/$VM_NAME.vmdk"

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
    
    # Check ISO file
    if [ ! -f "$ISO_PATH" ]; then
        log_error "Ubuntu ISO not found: $ISO_PATH"
        log_info "Download Ubuntu 22.04 Desktop ISO from:"
        log_info "https://ubuntu.com/download/desktop"
        exit 1
    fi
    
    # Check if VM already exists
    if [ -d "$VM_DIR" ]; then
        log_warning "VM directory already exists: $VM_DIR"
        read -p "Remove existing VM? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing VM..."
            vmrun stop "$VMX_FILE" 2>/dev/null || true
            vmrun deleteVM "$VMX_FILE" 2>/dev/null || true
            rm -rf "$VM_DIR"
        else
            log_info "Skipping VM creation"
            exit 0
        fi
    fi
    
    log_success "Prerequisites OK"
}

create_vm_directory() {
    log_info "Creating VM directory structure..."
    
    mkdir -p "$VM_DIR"
    log_success "VM directory created: $VM_DIR"
}

create_vmx_file() {
    log_info "Creating VMX configuration file..."
    
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

# CD/DVD Configuration
ide1:0.present = "TRUE"
ide1:0.fileName = "$ISO_PATH"
ide1:0.deviceType = "cdrom-image"

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

# Boot Configuration
bios.bootOrder = "cdrom,hdd"

# Tools
tools.syncTime = "TRUE"
tools.upgrade.policy = "upgradeAtPowerOn"

# Power Options
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
EOF

    log_success "VMX file created"
}

create_virtual_disk() {
    log_info "Creating virtual disk (${DISK_SIZE_MB}MB)..."
    
    # Create the virtual disk using vmware-vdiskmanager
    vmware-vdiskmanager -c -s ${DISK_SIZE_MB}MB -a lsilogic -t 0 "$VMDK_FILE"
    
    log_success "Virtual disk created"
}

setup_unattended_install() {
    log_info "Setting up unattended installation..."
    
    # Create cloud-init directory in VM
    CLOUD_INIT_DIR="$VM_DIR/cloud-init"
    mkdir -p "$CLOUD_INIT_DIR"
    
    # Copy cloud-init files
    cp "${cloud_init_file}" "$CLOUD_INIT_DIR/user-data"
    cp "${network_config}" "$CLOUD_INIT_DIR/network-config"
    
    # Create meta-data
    cat > "$CLOUD_INIT_DIR/meta-data" << EOF
instance-id: $VM_NAME-$(date +%s)
local-hostname: $VM_NAME
EOF
    
    log_success "Cloud-init configuration prepared"
}

start_vm() {
    log_info "Starting VM $VM_NAME..."
    
    vmrun -T ws start "$VMX_FILE"
    
    log_success "VM started"
    log_info "VM will boot from ISO and begin Ubuntu installation"
    log_info "Installation will be automated via cloud-init"
}

wait_for_installation() {
    log_info "Waiting for Ubuntu installation to complete..."
    log_info "This may take 10-15 minutes..."
    
    # Wait for VM to be responsive on SSH
    TIMEOUT=1800  # 30 minutes
    ELAPSED=0
    INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if ping -c 1 "$IP_ADDRESS" >/dev/null 2>&1; then
            log_info "VM is responding to ping"
            
            # Try SSH connection
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               devops@"$IP_ADDRESS" 'echo "SSH ready"' >/dev/null 2>&1; then
                log_success "Ubuntu installation completed!"
                log_success "VM is ready at $IP_ADDRESS"
                return 0
            fi
        fi
        
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        log_info "Installation progress: $((ELAPSED / 60)) minutes elapsed..."
    done
    
    log_error "Installation timeout reached"
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
    echo "   SSH: ssh devops@$IP_ADDRESS"
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
    log_info "🚀 Creating VMware VM: $VM_NAME"
    echo ""
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Create VM structure
    create_vm_directory
    create_vmx_file
    create_virtual_disk
    
    # Step 3: Setup installation
    setup_unattended_install
    
    # Step 4: Start VM
    start_vm
    
    # Step 5: Wait for installation
    wait_for_installation
    
    # Step 6: Show results
    show_vm_info
}

# Execute main function
main "$@"
