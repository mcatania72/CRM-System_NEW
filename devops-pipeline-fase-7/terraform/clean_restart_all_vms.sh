#!/bin/bash

# =============================================================================
# CLEAN RESTART - Pulizia completa e rilancio con autoinstall corretto
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}        CLEAN RESTART - AUTOINSTALL COMPLETO E CORRETTO${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# =============================================================================
# STEP 1: PULIZIA COMPLETA
# =============================================================================
echo -e "${YELLOW}STEP 1: PULIZIA COMPLETA${NC}"
echo ""

# Stop tutte le VM
echo "Fermando tutte le VM..."
vmrun list | grep -v "Total" | while read vm; do
    echo "  Stopping: $vm"
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 3

# Rimuovi directory VM
echo "Rimuovendo directory VM..."
sudo rm -rf ~/VMware_VMs/SPESE_*
sudo rm -rf ~/VMware_VMs/ubuntu-cloud-template

# Rimuovi ISO vecchi
echo "Rimuovendo ISO vecchi..."
rm -f *-autoinstall.iso

# Verifica pulizia
echo ""
echo "Verifica pulizia:"
echo "  VM attive: $(vmrun list | head -1)"
echo "  Directory SPESE: $(ls ~/VMware_VMs/ 2>/dev/null | grep -c SPESE || echo "0") trovate"
echo "  ISO files: $(ls *-autoinstall.iso 2>/dev/null | wc -l) trovati"
echo ""

# =============================================================================
# STEP 2: CREAZIONE ISO CORRETTI
# =============================================================================
echo -e "${YELLOW}STEP 2: CREAZIONE ISO AUTOINSTALL CORRETTI${NC}"
echo ""

# Funzione per creare ISO con autoinstall corretto
create_working_autoinstall_iso() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    echo "Creating autoinstall ISO for $VM_NAME..."
    
    WORK_DIR="/tmp/iso-$VM_NAME-$$"
    mkdir -p "$WORK_DIR/source-files"
    
    # Extract Ubuntu ISO
    echo "  Extracting Ubuntu ISO..."
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$WORK_DIR/source-files" >/dev/null 2>&1
    
    # Create autoinstall directory
    mkdir -p "$WORK_DIR/source-files/autoinstall"
    
    # Create user-data con fix per late-commands
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
    - docker.io
    - curl
    - wget
    - git
    - net-tools
    - apt-transport-https
    - ca-certificates
    - gnupg
    - lsb-release
  late-commands:
    # Sistema base
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    # Network fix
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
    # Docker setup sicuro
    - curtin in-target --target=/target -- systemctl enable docker.service || echo "Docker service enable attempted"
    - curtin in-target --target=/target -- systemctl enable containerd.service || echo "Containerd service enable attempted"
    # User setup post-install
    - |
      cat > /target/etc/systemd/system/docker-user-setup.service << EOF
      [Unit]
      Description=Docker user setup
      After=docker.service
      
      [Service]
      Type=oneshot
      ExecStart=/bin/bash -c 'groupadd -f docker && usermod -aG docker devops'
      RemainAfterExit=yes
      
      [Install]
      WantedBy=multi-user.target
      EOF
    - curtin in-target --target=/target -- systemctl enable docker-user-setup.service
    # Kubernetes prep
    - echo "br_netfilter" >> /target/etc/modules-load.d/k8s.conf
    - |
      cat > /target/etc/sysctl.d/k8s.conf << EOF
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1
      net.ipv4.ip_forward = 1
      EOF
    # Completion marker
    - touch /target/home/devops/autoinstall-complete
    - echo "${VM_NAME}" > /target/home/devops/vm-role-${VM_ROLE}
    # Fix permissions
    - curtin in-target --target=/target -- chown -R devops:devops /home/devops
USERDATA

    # Create meta-data
    cat > "$WORK_DIR/source-files/autoinstall/meta-data" << METADATA
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME,,}
METADATA

    # Modify GRUB for automatic boot (no menu)
    cat > "$WORK_DIR/source-files/boot/grub/grub.cfg" << 'GRUBCFG'
set default="0"
set timeout=1

menuentry "Autoinstall Ubuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd  /casper/initrd
}
GRUBCFG

    # Create ISO
    echo "  Creating ISO..."
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
    
    echo "  ✓ Created $VM_NAME-autoinstall.iso"
}

# Crea tutti gli ISO
create_working_autoinstall_iso "SPESE_FE_VM" "192.168.1.101" "master"
create_working_autoinstall_iso "SPESE_BE_VM" "192.168.1.102" "worker"
create_working_autoinstall_iso "SPESE_DB_VM" "192.168.1.103" "worker"

echo ""
echo "Verifica ISO creati:"
ls -la *-autoinstall.iso
echo ""

# =============================================================================
# STEP 3: RICREA E AVVIA VM CON TERRAFORM
# =============================================================================
echo -e "${YELLOW}STEP 3: RICREA E AVVIA VM CON TERRAFORM${NC}"
echo ""

# Pulisci stato Terraform per forzare ricreazione
echo "Pulizia stato Terraform..."
terraform destroy -auto-approve 2>/dev/null || echo "  (nessuno stato da distruggere)"
rm -f terraform.tfstate* .terraform.lock.hcl tfplan
rm -rf .terraform/

# Re-init Terraform
echo "Re-init Terraform..."
terraform init

# Plan
echo "Terraform plan..."
terraform plan -out=tfplan

# Apply
echo ""
echo -e "${GREEN}Avvio creazione VM con autoinstall corretto...${NC}"
terraform apply tfplan

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                    DEPLOYMENT AVVIATO!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Le VM stanno installando Ubuntu automaticamente."
echo "Tempo stimato: 15-20 minuti per VM"
echo ""
echo "Monitora il progresso con:"
echo "  watch 'vmrun list && echo \"\" && ping -c 1 192.168.1.101 2>/dev/null || echo \"FE not ready\" && ping -c 1 192.168.1.102 2>/dev/null || echo \"BE not ready\" && ping -c 1 192.168.1.103 2>/dev/null || echo \"DB not ready\"'"
echo ""
echo "Una volta pronte, testa con:"
echo "  ssh devops@192.168.1.101  # password: devops"
echo "  ssh devops@192.168.1.102"
echo "  ssh devops@192.168.1.103"
