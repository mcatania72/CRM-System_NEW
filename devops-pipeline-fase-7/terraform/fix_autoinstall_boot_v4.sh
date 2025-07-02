#!/bin/bash

# =============================================================================
# FIX AUTOINSTALL BOOT V4 - GRUB ZERO TIMEOUT + AUTOINSTALL DEFAULT
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX AUTOINSTALL BOOT V4 - ZERO TIMEOUT ===${NC}"
echo ""

# Stop VM prima di modificare ISO
echo "Stopping VMs per modificare ISO..."
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx" hard 2>/dev/null || true
sleep 3

# Genera hash password corretto
PASSWORD_HASH='$6$qVrrPAH4LejqI.n7$Ah7csxIG5sVzCeowc0vGF7XZZ3KCT1xnZGV.S.K4hnkjs9k8ZQc9LjO6F8juZt7RgxJBgNXJ6gUOctJYqLqjP/'

# Funzione per creare ISO con GRUB timeout=0
create_zero_timeout_iso() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    echo "Creating ZERO TIMEOUT ISO for $VM_NAME..."
    
    WORK_DIR="/tmp/iso-$VM_NAME-$$"
    mkdir -p "$WORK_DIR/source-files"
    
    # Extract Ubuntu ISO
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$WORK_DIR/source-files" >/dev/null 2>&1
    
    # Create autoinstall directory
    mkdir -p "$WORK_DIR/source-files/autoinstall"
    
    # Create user-data
    cat > "$WORK_DIR/source-files/autoinstall/user-data" << USERDATA
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    ethernets:
      ens33:
        dhcp4: false
        addresses:
          - ${IP_ADDRESS}/24
        gateway4: 192.168.1.1
        nameservers:
          addresses: [8.8.8.8, 8.8.4.4]
    version: 2
  identity:
    hostname: ${VM_NAME,,}
    password: '${PASSWORD_HASH}'
    username: devops
  ssh:
    allow-pw: true
    install-server: true
  storage:
    layout:
      name: direct
  packages:
    - openssh-server
    - curl
    - git
  late-commands:
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    - curtin in-target --target=/target -- systemctl enable ssh
USERDATA

    # Create meta-data
    echo "instance-id: ${VM_NAME}" > "$WORK_DIR/source-files/autoinstall/meta-data"
    
    # GRUB con ZERO timeout e autoinstall default
    cat > "$WORK_DIR/source-files/boot/grub/grub.cfg" << 'GRUBCFG'
set default="autoinstall"
set timeout=0
set timeout_style=hidden

menuentry "autoinstall" {
    linux /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd /casper/initrd
}
GRUBCFG

    # Create ISO
    cd "$WORK_DIR/source-files"
    genisoimage -r -V "Ubuntu Zero Timeout" \
        -cache-inodes -J -l -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/$VM_NAME-autoinstall.iso" \
        . >/dev/null 2>&1
    
    cd - >/dev/null
    rm -rf "$WORK_DIR"
    
    echo "✓ Created $VM_NAME-autoinstall.iso (ZERO TIMEOUT)"
}

# Crea tutti gli ISO
create_zero_timeout_iso "SPESE_FE_VM" "192.168.1.101" "master"
create_zero_timeout_iso "SPESE_BE_VM" "192.168.1.102" "worker"
create_zero_timeout_iso "SPESE_DB_VM" "192.168.1.103" "worker"

echo ""
echo -e "${GREEN}=== ISO CREATI CON ZERO TIMEOUT ===${NC}"
echo ""
echo "GRUB Configuration:"
echo "  - timeout=0 (boot immediato)"
echo "  - timeout_style=hidden (no menu)"
echo "  - default=autoinstall"
echo ""
echo "Riavvia le VM:"
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\""
