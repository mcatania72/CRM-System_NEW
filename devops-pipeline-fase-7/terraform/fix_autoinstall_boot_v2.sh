#!/bin/bash

# =============================================================================
# FIX AUTOINSTALL BOOT - VERSIONE 2 - SENZA DOCKER NEI LATE COMMANDS
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX AUTOINSTALL BOOT MENU V2 ===${NC}"
echo ""

# Check existing ISOs
for ISO in SPESE_*-autoinstall.iso; do
    if [ -f "$ISO" ]; then
        echo -e "${YELLOW}Fixing $ISO...${NC}"
        
        # Mount ISO to check
        MOUNT_DIR="/tmp/iso-check-$$"
        mkdir -p "$MOUNT_DIR"
        sudo mount -o loop "$ISO" "$MOUNT_DIR" 2>/dev/null || {
            echo -e "  ${RED}Cannot mount ISO${NC}"
            continue
        }
        
        # Check GRUB config
        if [ -f "$MOUNT_DIR/boot/grub/grub.cfg" ]; then
            echo "  Checking GRUB config..."
            grep -q "autoinstall" "$MOUNT_DIR/boot/grub/grub.cfg" && echo "  ✓ Autoinstall entry found" || echo "  ✗ Autoinstall entry missing"
        fi
        
        # Check autoinstall directory
        if [ -d "$MOUNT_DIR/autoinstall" ]; then
            echo "  ✓ Autoinstall directory found"
            ls -la "$MOUNT_DIR/autoinstall/" 2>/dev/null || true
        else
            echo "  ✗ Autoinstall directory missing"
        fi
        
        sudo umount "$MOUNT_DIR" 2>/dev/null || true
        rmdir "$MOUNT_DIR"
        
        echo ""
    fi
done

echo -e "${BLUE}=== RICREAZIONE ISO CON BOOT DIRETTO V2 ===${NC}"
echo ""

# Function to create autoinstall ISO - SENZA DOCKER
cat > create_autoinstall_iso_fixed.sh << 'EOF'
#!/bin/bash

set -e

# Create autoinstall ISO with automatic boot - NO DOCKER IN LATE COMMANDS
create_autoinstall_iso() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    echo "Creating autoinstall ISO for $VM_NAME..."
    
    WORK_DIR="/tmp/iso-$VM_NAME-$$"
    mkdir -p "$WORK_DIR/source-files"
    
    # Extract Ubuntu ISO
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$WORK_DIR/source-files" >/dev/null 2>&1
    
    # Create autoinstall directory
    mkdir -p "$WORK_DIR/source-files/autoinstall"
    
    # Create user-data - MINIMAL VERSION WITHOUT DOCKER
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
          addresses:
            - 8.8.8.8
            - 8.8.4.4
    version: 2
  apt:
    disable_components: []
    geoip: true
    preserve_sources_list: false
    primary:
      - arches: [amd64, i386]
        uri: http://archive.ubuntu.com/ubuntu
      - arches: [default]
        uri: http://ports.ubuntu.com/ubuntu-ports
  identity:
    hostname: ${VM_NAME,,}
    password: \$6\$xyz\$74AlwKA3Z5n2L6ujMzm/zQXHCluA4SRc2mBfO2/O5uUc2yM2n2tnbBMi/IVRLJuKwfjrLZjAT7arSy/
    username: devops
  ssh:
    allow-pw: true
    install-server: true
  storage:
    layout:
      name: direct
  packages:
    - curl
    - wget
    - git
    - net-tools
    - vim
    - htop
  late-commands:
    # Solo comandi essenziali che non possono fallire
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    # Network configuration persistente
    - |
      cat > /target/etc/netplan/00-installer-config.yaml << EOF
      network:
        version: 2
        ethernets:
          ens33:
            dhcp4: false
            addresses:
              - ${IP_ADDRESS}/24
            gateway4: 192.168.1.1
            nameservers:
              addresses:
                - 8.8.8.8
                - 8.8.4.4
      EOF
    - chmod 600 /target/etc/netplan/00-installer-config.yaml
    # Marker file per sapere che autoinstall è completato
    - touch /target/home/devops/autoinstall-complete
    - echo "${VM_NAME}" > /target/home/devops/vm-name
    - echo "${VM_ROLE}" > /target/home/devops/vm-role
    # Fix permissions
    - chown -R 1000:1000 /target/home/devops
USERDATA

    # Create meta-data
    cat > "$WORK_DIR/source-files/autoinstall/meta-data" << METADATA
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME,,}
METADATA

    # Modify GRUB to autoboot without menu
    cat > "$WORK_DIR/source-files/boot/grub/grub.cfg" << 'GRUBCFG'
set default="0"
set timeout=1

menuentry "Autoinstall Ubuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd  /casper/initrd
}
GRUBCFG

    # Create ISO with autoinstall
    cd "$WORK_DIR/source-files"
    genisoimage -r -V "Ubuntu Autoinstall" \
        -cache-inodes -J -l \
        -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot -boot-load-size 4 \
        -boot-info-table \
        -o "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/$VM_NAME-autoinstall.iso" \
        . >/dev/null 2>&1
    
    cd - >/dev/null
    rm -rf "$WORK_DIR"
    
    echo "✓ Created $VM_NAME-autoinstall.iso"
}

# Recreate all ISOs without Docker in late-commands
create_autoinstall_iso "SPESE_FE_VM" "192.168.1.101" "master"
create_autoinstall_iso "SPESE_BE_VM" "192.168.1.102" "worker"
create_autoinstall_iso "SPESE_DB_VM" "192.168.1.103" "worker"

echo ""
echo "All autoinstall ISOs recreated with automatic boot (NO DOCKER)!"
EOF

chmod +x create_autoinstall_iso_fixed.sh
./create_autoinstall_iso_fixed.sh

echo ""
echo -e "${GREEN}=== FIX COMPLETATO V2 ===${NC}"
echo ""
echo "ISO ricreati SENZA Docker nei late-commands."
echo ""
echo "NOTA: Docker/containerd verrà installato dopo con K3s!"
echo ""
echo "Per riavviare le VM con i nuovi ISO:"
echo ""
echo "vmrun stop \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\" hard"
echo "vmrun stop \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\" hard"
echo "vmrun stop \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\" hard"
echo ""
echo "sleep 5"
echo ""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\""
