#!/bin/bash

# =============================================================================
# VM CREATION SCRIPT - UBUNTU AUTOINSTALL APPROACH
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
AUTOINSTALL_ISO="${autoinstall_iso}"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"
USERNAME="${username}"

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
    
    # Check autoinstall ISO exists
    if [ ! -f "$AUTOINSTALL_ISO" ]; then
        log_error "Autoinstall ISO not found: $AUTOINSTALL_ISO"
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

create_vm_directory() {
    log_info "Creating VM directory structure..."
    mkdir -p "$VM_DIR"
    log_success "VM directory created: $VM_DIR"
}

create_virtual_disk() {
    log_info "Creating virtual disk (${disk_size_mb}MB)..."
    
    # Use vmware-vdiskmanager to create proper VMDK
    if command -v vmware-vdiskmanager &> /dev/null; then
        log_info "Using vmware-vdiskmanager..."
        vmware-vdiskmanager -c -s ${disk_size_mb}MB -a lsilogic -t 0 "$VMDK_FILE"
    else
        log_error "vmware-vdiskmanager not found!"
        exit 1
    fi
    
    log_success "Virtual disk created"
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

# CD/DVD Configuration - Autoinstall ISO
ide1:0.present = "TRUE"
ide1:0.fileName = "$(realpath $AUTOINSTALL_ISO)"
ide1:0.deviceType = "cdrom-image"

# Boot Configuration
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "2000"

# Other Settings
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
EOF

    log_success "VMX file created"
}

start_vm() {
    log_info "Starting VM $VM_NAME with autoinstall..."
    
    # Start VM with retry logic
    RETRY=3
    while [ $RETRY -gt 0 ]; do
        if vmrun -T ws start "$VMX_FILE" 2>&1; then
            log_success "VM started successfully"
            break
        else
            log_warning "Failed to start VM, retries left: $((RETRY-1))"
            RETRY=$((RETRY-1))
            if [ $RETRY -gt 0 ]; then
                sleep 5
            else
                log_error "Failed to start VM after 3 attempts"
                exit 1
            fi
        fi
    done
    
    log_info "Ubuntu autoinstall will begin automatically"
    log_info "Installation takes approximately 15-20 minutes"
}

wait_for_installation() {
    log_info "Waiting for Ubuntu autoinstall to complete..."
    
    # SIMPLIFIED: Just wait with timeout, no SSH checks
    TIMEOUT=1200  # 20 minutes
    ELAPSED=0
    INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        
        # Simple progress update
        MINUTES=$((ELAPSED / 60))
        log_info "Installation progress: $MINUTES minutes elapsed (max 20 minutes)..."
        
        # Check if VM is still running
        if ! vmrun list | grep -q "$VMX_FILE"; then
            log_error "VM stopped unexpectedly!"
            exit 1
        fi
    done
    
    log_warning "Installation timeout reached after 20 minutes"
    log_info "VM installation may continue in background"
}

show_vm_info() {
    echo ""
    log_success "🎉 VM $VM_NAME CREATED!"
    echo ""
    echo -e "$${GREEN}📊 VM Details:$${NC}"
    echo "   Name: $VM_NAME"
    echo "   IP Address: $IP_ADDRESS"
    echo "   Memory: $${MEMORY_MB}MB"
    echo "   CPU Cores: $NUM_CPUS"
    echo "   Disk: $${DISK_SIZE_MB}MB"
    echo ""
    echo -e "$${YELLOW}📋 Status:$${NC}"
    echo "   VM is running. Installation may still be in progress."
    echo "   Check in ~15-20 minutes:"
    echo "   ssh $USERNAME@$IP_ADDRESS"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🚀 Creating VMware VM: $VM_NAME"
    echo ""
    
    # Execution steps
    check_prerequisites
    create_vm_directory
    create_virtual_disk
    create_vmx_file
    start_vm
    wait_for_installation
    show_vm_info
    
    # Always exit with success after timeout
    exit 0
}

# Execute main function
main "$@"
