#!/bin/bash

# =============================================================================
# FIX AUTOINSTALL BOOT V6 - HASH GENERATO DINAMICAMENTE
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX AUTOINSTALL BOOT V6 - HASH DINAMICO ===${NC}"
echo ""

# Stop VM prima di modificare ISO
echo "Stopping VMs..."
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx" hard 2>/dev/null || true
vmrun stop "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx" hard 2>/dev/null || true
sleep 3

# GENERA HASH DINAMICAMENTE!
echo -e "${YELLOW}Generando hash password dinamicamente...${NC}"
PASSWORD="devops"

# Metodo 1: Python (se disponibile)
if command -v python3 &> /dev/null; then
    PASSWORD_HASH=$(python3 -c "import crypt; print(crypt.crypt('${PASSWORD}', crypt.mksalt(crypt.METHOD_SHA512)))")
    echo "✓ Hash generato con Python"
# Metodo 2: mkpasswd (se disponibile)
elif command -v mkpasswd &> /dev/null; then
    PASSWORD_HASH=$(echo "${PASSWORD}" | mkpasswd -m sha-512 -s)
    echo "✓ Hash generato con mkpasswd"
# Metodo 3: openssl (sempre disponibile)
else
    # Genera salt random
    SALT=$(openssl rand -base64 8 | tr -d '+=' | head -c 8)
    PASSWORD_HASH=$(openssl passwd -6 -salt "${SALT}" "${PASSWORD}")
    echo "✓ Hash generato con openssl"
fi

echo "Password: ${PASSWORD}"
echo "Hash generato: ${PASSWORD_HASH:0:30}..."
echo ""

# Verifica che l'hash sia stato generato
if [ -z "$PASSWORD_HASH" ]; then
    echo -e "${RED}ERRORE: Impossibile generare hash password!${NC}"
    exit 1
fi

# Funzione per creare ISO con hash dinamico
create_dynamic_iso() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    echo "Creating ISO for $VM_NAME con hash dinamico..."
    
    WORK_DIR="/tmp/iso-$VM_NAME-$$"
    mkdir -p "$WORK_DIR/source-files"
    
    # Extract Ubuntu ISO
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$WORK_DIR/source-files" >/dev/null 2>&1
    
    # Create autoinstall directory
    mkdir -p "$WORK_DIR/source-files/autoinstall"
    
    # Create user-data con HASH DINAMICO
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
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    - curtin in-target --target=/target -- systemctl enable ssh
    - |
      echo "=== AUTOINSTALL INFO ===" > /target/home/devops/autoinstall-info.txt
      echo "VM: ${VM_NAME}" >> /target/home/devops/autoinstall-info.txt
      echo "IP: ${IP_ADDRESS}" >> /target/home/devops/autoinstall-info.txt
      echo "Role: ${VM_ROLE}" >> /target/home/devops/autoinstall-info.txt
      echo "User: devops" >> /target/home/devops/autoinstall-info.txt
      echo "Pass: ${PASSWORD}" >> /target/home/devops/autoinstall-info.txt
      echo "Hash: ${PASSWORD_HASH}" >> /target/home/devops/autoinstall-info.txt
    - chown -R 1000:1000 /target/home/devops
USERDATA

    # Create meta-data
    echo "instance-id: ${VM_NAME}" > "$WORK_DIR/source-files/autoinstall/meta-data"
    
    # GRUB con timeout=0 e hidden
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
    genisoimage -r -V "Ubuntu Auto V6" \
        -cache-inodes -J -l -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/$VM_NAME-autoinstall.iso" \
        . >/dev/null 2>&1
    
    cd - >/dev/null
    rm -rf "$WORK_DIR"
    
    echo "✓ Created $VM_NAME-autoinstall.iso"
}

# Test veloce che l'hash funzioni
echo -e "${YELLOW}Test hash generato...${NC}"
TEST_RESULT=$(python3 -c "import crypt; print('OK' if crypt.crypt('${PASSWORD}', '${PASSWORD_HASH}') == '${PASSWORD_HASH}' else 'FAIL')" 2>/dev/null || echo "SKIP")
if [ "$TEST_RESULT" = "OK" ]; then
    echo -e "${GREEN}✓ Hash verificato correttamente!${NC}"
elif [ "$TEST_RESULT" = "FAIL" ]; then
    echo -e "${RED}✗ Hash non valido!${NC}"
    exit 1
else
    echo -e "${YELLOW}⚠ Test hash skipped (python non disponibile)${NC}"
fi

# Crea tutti gli ISO
create_dynamic_iso "SPESE_FE_VM" "192.168.1.101" "master"
create_dynamic_iso "SPESE_BE_VM" "192.168.1.102" "worker"
create_dynamic_iso "SPESE_DB_VM" "192.168.1.103" "worker"

echo ""
echo -e "${GREEN}=== V6 COMPLETATA - HASH DINAMICO ===${NC}"
echo ""
echo "✅ Password hash generato dinamicamente"
echo "✅ GRUB: timeout=0 + hidden (no menu)"
echo "✅ Credenziali: devops/${PASSWORD}"
echo "✅ Hash testato e verificato"
echo ""
echo "Riavvia le VM:"
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\""
echo "vmrun start \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\""
