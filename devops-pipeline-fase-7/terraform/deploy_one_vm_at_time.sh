#!/bin/bash

# =============================================================================
# DEPLOY UNA VM ALLA VOLTA - Approccio controllato
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}              DEPLOY CONTROLLATO - UNA VM ALLA VOLTA${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Funzione per creare ISO semplice
create_simple_iso() {
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
    
    # Create minimal user-data
    cat > "$WORK_DIR/source-files/autoinstall/user-data" << EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    ethernets:
      ens33:
        dhcp4: true
    version: 2
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
  late-commands:
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
EOF

    # Create meta-data
    echo "instance-id: $VM_NAME" > "$WORK_DIR/source-files/autoinstall/meta-data"
    
    # Create ISO
    cd "$WORK_DIR/source-files"
    genisoimage -r -V "Ubuntu Autoinstall" \
        -cache-inodes -J -l \
        -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot -boot-load-size 4 \
        -boot-info-table \
        -o "$(pwd)/$VM_NAME-autoinstall.iso" \
        . >/dev/null 2>&1
    
    # Move ISO to terraform directory
    mv "$VM_NAME-autoinstall.iso" "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/"
    
    cd - >/dev/null
    rm -rf "$WORK_DIR"
    
    echo "✓ Created $VM_NAME-autoinstall.iso"
}

# Menu per selezione VM
echo -e "${YELLOW}Quale VM vuoi deployare per prima?${NC}"
echo ""
echo "1) SPESE_FE_VM (Frontend - Master K8s)"
echo "2) SPESE_BE_VM (Backend - Worker K8s)"
echo "3) SPESE_DB_VM (Database - Worker K8s)"
echo "4) Tutte in sequenza (una alla volta)"
echo ""
read -p "Scelta (1-4): " choice

case $choice in
    1)
        TARGET_VM="FE"
        VM_NAME="SPESE_FE_VM"
        IP_ADDRESS="192.168.1.101"
        VM_ROLE="master"
        ;;
    2)
        TARGET_VM="BE"
        VM_NAME="SPESE_BE_VM"
        IP_ADDRESS="192.168.1.102"
        VM_ROLE="worker"
        ;;
    3)
        TARGET_VM="DB"
        VM_NAME="SPESE_DB_VM"
        IP_ADDRESS="192.168.1.103"
        VM_ROLE="worker"
        ;;
    4)
        echo "Deploy sequenziale di tutte le VM..."
        TARGET_VM="ALL"
        ;;
    *)
        echo "Scelta non valida"
        exit 1
        ;;
esac

# Deploy singola VM
deploy_single_vm() {
    local target="$1"
    local vm_name="$2"
    local ip="$3"
    local role="$4"
    
    echo ""
    echo -e "${BLUE}=== DEPLOYING $vm_name ===${NC}"
    echo ""
    
    # Crea ISO
    create_simple_iso "$vm_name" "$ip" "$role"
    
    # Terraform init se necessario
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    # Apply solo per questa VM
    echo "Creating VM with Terraform..."
    terraform apply -target='null_resource.create_autoinstall_iso["'$target'"]' -auto-approve
    terraform apply -target='null_resource.create_vms["'$target'"]' -auto-approve
    
    echo ""
    echo -e "${GREEN}$vm_name deployment started!${NC}"
    echo ""
    echo "Monitor con:"
    echo "  vmrun list"
    echo "  ping -c 1 $ip"
    echo ""
    echo "Attendi che risponda al ping prima di procedere con la prossima VM"
    
    if [ "$TARGET_VM" != "ALL" ]; then
        echo ""
        echo "Vuoi monitorare l'installazione? (y/n)"
        read -p "> " monitor
        if [ "$monitor" = "y" ]; then
            watch -n 10 "vmrun list && echo '' && ping -c 1 $ip 2>/dev/null && echo '✓ VM risponde!' || echo '✗ VM non ancora pronta'"
        fi
    fi
}

# Esegui deployment
if [ "$TARGET_VM" = "ALL" ]; then
    # Deploy sequenziale
    deploy_single_vm "FE" "SPESE_FE_VM" "192.168.1.101" "master"
    
    echo ""
    echo -e "${YELLOW}Attendi che FE_VM sia pronta prima di continuare...${NC}"
    read -p "Premi Enter quando FE_VM risponde al ping..."
    
    deploy_single_vm "BE" "SPESE_BE_VM" "192.168.1.102" "worker"
    
    echo ""
    echo -e "${YELLOW}Attendi che BE_VM sia pronta prima di continuare...${NC}"
    read -p "Premi Enter quando BE_VM risponde al ping..."
    
    deploy_single_vm "DB" "SPESE_DB_VM" "192.168.1.103" "worker"
else
    # Deploy singola VM selezionata
    deploy_single_vm "$TARGET_VM" "$VM_NAME" "$IP_ADDRESS" "$VM_ROLE"
fi

echo ""
echo -e "${GREEN}=== DEPLOYMENT COMPLETATO ===${NC}"
echo ""
echo "Prossimi passi:"
echo "1. Verifica che la VM risponda al ping"
echo "2. SSH nella VM: ssh devops@<IP>"
echo "3. Verifica Docker: docker --version"
echo "4. Procedi con la prossima VM"
