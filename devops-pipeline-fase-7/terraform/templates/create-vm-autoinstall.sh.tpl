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
    
    # Check genisoimage for ISO creation
    if ! command -v genisoimage &> /dev/null; then
        log_error "genisoimage not found! Installing..."
        sudo apt-get update && sudo apt-get install -y genisoimage
    fi
    
    # Check 7z for ISO extraction
    if ! command -v 7z &> /dev/null; then
        log_error "7z not found! Installing..."
        sudo apt-get update && sudo apt-get install -y p7zip-full
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
        log_info "vmware-vdiskmanager not found, using vmkfstools alternative..."
        
        # Create VMDK using basic sparse format
        # First create the data file
        dd if=/dev/zero of="$VM_DIR/$VM_NAME-flat.vmdk" bs=1M count=0 seek=$((DISK_SIZE_MB)) 2>/dev/null
        
        # Create proper descriptor
        cat > "$VMDK_FILE" << EOF
# Disk DescriptorFile
version=1
encoding="UTF-8"
CID=fffffffe
parentCID=ffffffff
isNativeSnapshot="no"
createType="vmfs"

# Extent description
RW $((DISK_SIZE_MB * 2048)) VMFS "$VM_NAME-flat.vmdk"

# The Disk Data Base
#DDB

ddb.virtualHWVersion = "19"
ddb.longContentID = "$(openssl rand -hex 16)"
ddb.uuid = "$(uuidgen | tr '[:upper:]' '[:lower:]')"
ddb.geometry.cylinders = "$((DISK_SIZE_MB / 16))"
ddb.geometry.heads = "16"
ddb.geometry.sectors = "63"
ddb.adapterType = "lsilogic"
EOF
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

# USB Configuration
usb.present = "TRUE"
ehci.present = "TRUE"
ehci.pciSlotNumber = "35"

# Sound Configuration
sound.present = "TRUE"
sound.fileName = "-1"
sound.autodetect = "TRUE"

# CD/DVD Configuration - Autoinstall ISO
ide1:0.present = "TRUE"
ide1:0.fileName = "$(realpath $AUTOINSTALL_ISO)"
ide1:0.deviceType = "cdrom-image"

# Boot Configuration
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "2000"

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
EOF

    log_success "VMX file created"
}

start_vm() {
    log_info "Starting VM $VM_NAME with autoinstall..."
    
    vmrun -T ws start "$VMX_FILE"
    
    log_success "VM started - Ubuntu autoinstall will begin automatically"
    log_info "Installation process:"
    log_info "  1. VM boots from autoinstall ISO"
    log_info "  2. Ubuntu installs automatically (15-20 minutes)"
    log_info "  3. System reboots and configures network"
    log_info "  4. SSH becomes available at $IP_ADDRESS"
}

wait_for_installation() {
    log_info "Waiting for Ubuntu autoinstall to complete..."
    log_info "This process takes approximately 15-20 minutes..."
    
    # Wait for installation to complete and SSH to be ready
    TIMEOUT=2400  # 40 minutes
    ELAPSED=0
    INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        # Check if VM is responding to ping
        if ping -c 1 "$IP_ADDRESS" >/dev/null 2>&1; then
            log_info "VM is responding to ping - checking SSH..."
            
            # Try SSH connection
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               $USERNAME@"$IP_ADDRESS" 'echo "SSH ready"' >/dev/null 2>&1; then
                log_success "Ubuntu autoinstall completed successfully!"
                log_success "VM is ready and accessible via SSH"
                return 0
            fi
        fi
        
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        log_info "Installation progress: $((ELAPSED / 60)) minutes elapsed..."
        
        # Show installation phases
        if [ $ELAPSED -eq 300 ]; then
            log_info "Phase: OS installation in progress..."
        elif [ $ELAPSED -eq 600 ]; then
            log_info "Phase: Package installation and configuration..."
        elif [ $ELAPSED -eq 900 ]; then
            log_info "Phase: System finalization and first boot..."
        elif [ $ELAPSED -eq 1200 ]; then
            log_info "Phase: Network configuration and services startup..."
        fi
    done
    
    log_error "Installation timeout reached"
    log_error "Check VM console for installation status"
    return 1
}

verify_installation() {
    log_info "Verifying installation completion..."
    
    # Test SSH connection and check autoinstall marker
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       $USERNAME@"$IP_ADDRESS" 'ls /home/'$USERNAME'/autoinstall-complete' >/dev/null 2>&1; then
        log_success "Autoinstall completion marker found"
    else
        log_warning "Autoinstall marker not found - installation may not be complete"
    fi
    
    # Check Docker installation
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
       $USERNAME@"$IP_ADDRESS" 'docker --version' >/dev/null 2>&1; then
        log_success "Docker installation verified"
    else
        log_warning "Docker not found or not accessible"
    fi
    
    # Check system info
    SYSTEM_INFO=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                  $USERNAME@"$IP_ADDRESS" 'uname -a && whoami' 2>/dev/null || echo "SSH connection failed")
    log_info "System info: $SYSTEM_INFO"
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
    echo "   SSH: ssh $USERNAME@$IP_ADDRESS"
    echo "   VMX File: $VMX_FILE"
    echo "   ISO: $AUTOINSTALL_ISO"
    echo ""
    echo -e "$${YELLOW}📋 Next Steps:$${NC}"
    echo "   1. Verify connectivity: ping $IP_ADDRESS"
    echo "   2. Test SSH: ssh $USERNAME@$IP_ADDRESS"
    echo "   3. Check Docker: ssh $USERNAME@$IP_ADDRESS 'docker --version'"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_info "🚀 Creating VMware VM with Ubuntu Autoinstall: $VM_NAME"
    echo ""
    
    # Debug info
    echo "Configuration:"
    echo "  VM_NAME: $VM_NAME"
    echo "  MEMORY_MB: $MEMORY_MB"
    echo "  NUM_CPUS: $NUM_CPUS"
    echo "  DISK_SIZE_MB: $DISK_SIZE_MB"
    echo "  AUTOINSTALL_ISO: $AUTOINSTALL_ISO"
    echo "  IP_ADDRESS: $IP_ADDRESS"
    echo "  VM_ROLE: $VM_ROLE"
    echo ""
    
    # Execution steps
    check_prerequisites
    create_vm_directory
    create_virtual_disk
    create_vmx_file
    start_vm
    wait_for_installation
    verify_installation
    show_vm_info
}

# Execute main function
main "$@"
