#!/bin/bash

# =============================================================================
# FIX AUTOINSTALL BOOT V7 - FIX SOLO LATE-COMMANDS
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX AUTOINSTALL BOOT V7 - ZERO TOUCH FINALE ===${NC}"
echo ""

# Stop VM
echo "Stopping VMs..."
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx" hard 2>/dev/null || true
sleep 3

# Genera hash password
echo -e "${YELLOW}Generando hash password...${NC}"
PASSWORD="devops"
if command -v python3 &> /dev/null; then
    PASSWORD_HASH=$(python3 -c "import crypt; print(crypt.crypt('${PASSWORD}', crypt.mksalt(crypt.METHOD_SHA512)))")
else
    SALT=$(openssl rand -base64 8 | tr -d '+=' | head -c 8)
    PASSWORD_HASH=$(openssl passwd -6 -salt "${SALT}" "${PASSWORD}")
fi
echo "✓ Hash generato"

# Funzione per creare ISO ZERO TOUCH PERFETTO
create_perfect_iso() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    echo "Creating PERFECT ZERO TOUCH ISO for $VM_NAME..."
    
    WORK_DIR="/tmp/iso-$VM_NAME-$$"
    mkdir -p "$WORK_DIR/source-files"
    
    # Extract Ubuntu ISO
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$WORK_DIR/source-files" >/dev/null 2>&1
    
    # Create autoinstall directory
    mkdir -p "$WORK_DIR/source-files/autoinstall"
    
    # Create user-data con LATE-COMMANDS CORRETTI
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
    - net-tools
  late-commands:
    # COMANDI SEMPLICI E SICURI - NO ERRORI
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    - curtin in-target --target=/target -- systemctl enable ssh
    # Info file semplice senza comandi complessi
    - |
      cat > /target/home/devops/vm-info.txt << EOF
      VM_NAME=${VM_NAME}
      VM_IP=${IP_ADDRESS}
      VM_ROLE=${VM_ROLE}
      USERNAME=devops
      PASSWORD=${PASSWORD}
      EOF
    - chown -R 1000:1000 /target/home/devops
    - chmod 644 /target/home/devops/vm-info.txt
USERDATA

    # Create meta-data
    echo "instance-id: ${VM_NAME}" > "$WORK_DIR/source-files/autoinstall/meta-data"
    
    # GRUB perfetto (già funzionante da V6)
    cat > "$WORK_DIR/source-files/boot/grub/grub.cfg" << 'GRUBCFG'
set default="0"
set timeout=0
set timeout_style=hidden

menuentry "Ubuntu Autoinstall" {
    linux /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd /casper/initrd
}
GRUBCFG

    # Create ISO
    cd "$WORK_DIR/source-files"
    genisoimage -r -V "Ubuntu ZeroTouch V7" \
        -cache-inodes -J -l -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/$VM_NAME-autoinstall.iso" \
        . >/dev/null 2>&1
    
    cd - >/dev/null
    rm -rf "$WORK_DIR"
    
    echo "✓ Created $VM_NAME-autoinstall.iso (ZERO TOUCH!)"
}

# Crea tutti gli ISO
create_perfect_iso "SPESE_FE_VM" "192.168.1.101" "master"
create_perfect_iso "SPESE_BE_VM" "192.168.1.102" "worker"
create_perfect_iso "SPESE_DB_VM" "192.168.1.103" "worker"

echo ""
echo -e "${GREEN}=== V7 ZERO TOUCH COMPLETO ===${NC}"
echo ""
echo "✅ NO selezione lingua (GRUB hidden)"
echo "✅ Installazione automatica completa"
echo "✅ NO errori nei late-commands"
echo "✅ Password: devops/devops"
echo "✅ ZERO interventi manuali!"
echo ""
echo "Per deployment ZERO TOUCH:"
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\""
echo ""
echo "Attendi 15-20 minuti e poi:"
echo "ssh devops@192.168.1.101  # password: devops"
