#!/bin/bash

# =============================================================================
# EMERGENCY FIX - Risolve problemi boot e VM
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== EMERGENCY FIX PER PROBLEMI VM ===${NC}"
echo ""

# Stop tutte le VM
echo "Stopping all VMs..."
vmrun list | grep -v "Total" | while read vm; do
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 3

# FIX 1: Verifica e ripara DB_VM
echo ""
echo -e "${YELLOW}FIX 1: Verifico DB_VM${NC}"
DB_VMX="$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx"

if [ ! -f "$DB_VMX" ]; then
    echo "✗ DB_VM non trovata - ricreo con Terraform"
    # Forza ricreazione solo DB
    terraform destroy -target='null_resource.create_vms["DB"]' -auto-approve
    terraform apply -target='null_resource.create_vms["DB"]' -auto-approve
else
    echo "✓ DB_VM VMX exists"
    # Fix path ISO
    ISO_PATH="$(pwd)/SPESE_DB_VM-autoinstall.iso"
    sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ISO_PATH\"|" "$DB_VMX"
    echo "  Fixed ISO path: $ISO_PATH"
fi

# FIX 2: Crea ISO con autoinstall che funziona davvero
echo ""
echo -e "${YELLOW}FIX 2: Creo ISO con cloud-init semplice${NC}"

# Usa approccio diverso: ISO minimo con solo cloud-init
create_simple_autoinstall() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    
    echo "Creating simple autoinstall for $VM_NAME..."
    
    # Crea directory temporanea
    WORK_DIR="/tmp/simple-iso-$VM_NAME"
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR/nocloud"
    
    # Meta-data minimo
    cat > "$WORK_DIR/nocloud/meta-data" << EOF
instance-id: $VM_NAME
local-hostname: ${VM_NAME,,}
EOF

    # User-data semplificato
    cat > "$WORK_DIR/nocloud/user-data" << EOF
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ${VM_NAME,,}
    password: \$6\$xyz\$74AlwKA3Z5n2L6ujMzm/zQXHCluA4SRc2mBfO2/O5uUc2yM2n2tnbBMi/IVRLJuKwfjrLZjAT7arSy/
    username: devops
  ssh:
    install-server: true
  late-commands:
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
EOF

    # Crea ISO cloud-init
    cd "$WORK_DIR"
    genisoimage -output "$HOME/CRM-Fase7/devops-pipeline-fase-7/terraform/$VM_NAME-cloud-init.iso" \
        -volid cidata -joliet -rock nocloud/
    cd - >/dev/null
    
    rm -rf "$WORK_DIR"
    echo "✓ Created $VM_NAME-cloud-init.iso"
}

# ALTERNATIVA: Scarica Ubuntu autoinstall ISO pre-fatto
echo ""
echo -e "${YELLOW}ALTERNATIVA CONSIGLIATA:${NC}"
echo ""
echo "Invece di fixare gli ISO, possiamo:"
echo ""
echo "1. OPZIONE MANUALE VELOCE (15 minuti totali):"
echo "   - Accetta il menu lingua manualmente (3 click)"
echo "   - Ubuntu si installa con config di default"
echo "   - Post-install: configura network e Docker"
echo ""
echo "2. OPZIONE PRESEED (funziona sempre):"
echo "   - Usa preseed.cfg invece di cloud-init"
echo "   - Boot con parametri kernel per preseed"
echo "   - 100% automatico garantito"
echo ""
echo "3. OPZIONE CLOUD IMAGE:"
echo "   - Usa Ubuntu Cloud Image (già pronta)"
echo "   - Solo configurazione cloud-init"
echo "   - Boot immediato, no installazione"
echo ""

echo -e "${GREEN}RACCOMANDAZIONE:${NC}"
echo "Vista la situazione, procedi con OPZIONE 1:"
echo ""
echo "# Per ogni VM (FE, BE, DB):"
echo "1. Nella console VMware, seleziona English"
echo "2. Premi Continue (o Enter)"
echo "3. Premi Continue ancora"
echo "4. L'installazione procede automatica"
echo "5. Dopo 10-15 minuti, configura manualmente"
echo ""
echo "È più veloce che debuggare l'autoinstall!"
