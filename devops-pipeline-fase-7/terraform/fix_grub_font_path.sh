#!/bin/bash

# Fix GRUB config con path corretti per Ubuntu ISO
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX GRUB CONFIG CON PATH CORRETTI ==="

# Analizza GRUB originale per path corretti
echo "Analizzando GRUB originale per path font corretti..."

MOUNT_DIR="/tmp/grub_original_$$"
mkdir -p "$MOUNT_DIR"

# Monta ISO Ubuntu originale
if sudo mount -o loop "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" "$MOUNT_DIR" 2>/dev/null; then
    echo "✅ ISO Ubuntu originale montato"
    
    # Trova path font corretto
    echo "Path font trovati:"
    find "$MOUNT_DIR" -name "*.pf2" | head -5
    
    # Analizza GRUB originale
    echo ""
    echo "GRUB originale (prime 20 righe):"
    head -20 "$MOUNT_DIR/boot/grub/grub.cfg"
    
    sudo umount "$MOUNT_DIR"
    rmdir "$MOUNT_DIR"
else
    echo "❌ Impossibile montare ISO originale"
fi

# Crea GRUB config corretto basato su originale Ubuntu
echo ""
echo "Creando ISO test con GRUB config corretto..."

VM_NAME="TEST_FIXED"
TEMP_DIR="/tmp/grub_fixed_$$"
mkdir -p "$TEMP_DIR/source-files"

# Estrai ISO base
7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$TEMP_DIR/source-files" >/dev/null

# Crea autoinstall files
mkdir -p "$TEMP_DIR/source-files/server"
cat > "$TEMP_DIR/source-files/server/user-data" << 'EOF'
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    version: 2
    ethernets:
      ens33:
        dhcp4: true
  identity:
    hostname: test-fixed
    username: devops
    password: '$6$rounds=4096$saltsalt$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm'
  ssh:
    install-server: true
    allow-pw: true
  storage:
    layout:
      name: lvm
  packages:
    - openssh-server
  late-commands:
    - 'echo "devops ALL=(ALL) NOPASSWD:ALL" > /target/etc/sudoers.d/devops'
  shutdown: reboot
EOF

cat > "$TEMP_DIR/source-files/server/meta-data" << 'EOF'
instance-id: test-fixed
local-hostname: test-fixed
EOF

# BACKUP GRUB originale
GRUB_CFG="$TEMP_DIR/source-files/boot/grub/grub.cfg"
cp "$GRUB_CFG" "$GRUB_CFG.backup"

# MODIFICA GRUB ESISTENTE (NON SOSTITUIRE COMPLETAMENTE)
echo "Modificando GRUB esistente per autoinstall automatico..."

# Aggiungi configurazione autoinstall all'inizio mantenendo tutto il resto
sed -i '1i# AUTOINSTALL CONFIGURATION - AUTOMATIC BOOT' "$GRUB_CFG"
sed -i '2i set timeout=0' "$GRUB_CFG"
sed -i '3i set timeout_style=hidden' "$GRUB_CFG"
sed -i '4i set default=0' "$GRUB_CFG"
sed -i '5i ' "$GRUB_CFG"

# Trova la prima menuentry e aggiunge autoinstall prima
FIRST_MENU_LINE=$(grep -n "menuentry" "$GRUB_CFG" | head -1 | cut -d: -f1)

if [ ! -z "$FIRST_MENU_LINE" ]; then
    # Inserisci autoinstall menuentry prima del primo menu esistente
    sed -i "${FIRST_MENU_LINE}i\\
menuentry \"Ubuntu Server Autoinstall (AUTO)\" {\\
    set gfxpayload=keep\\
    linux   /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/server/ quiet splash ---\\
    initrd  /casper/initrd\\
}\\
" "$GRUB_CFG"

    echo "✅ Menu autoinstall aggiunto alla riga $FIRST_MENU_LINE"
else
    echo "❌ Impossibile trovare menuentry nel GRUB"
fi

# Verifica modifiche
echo ""
echo "GRUB modificato (prime 15 righe):"
head -15 "$GRUB_CFG"

# Crea ISO corretto
echo ""
echo "Creando ISO con GRUB corretto..."
genisoimage -r -V "Ubuntu Fixed Autoinstall" \
    -cache-inodes -J -joliet-long -l \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "TEST-FIXED-autoinstall.iso" \
    "$TEMP_DIR/source-files" >/dev/null 2>&1

if [ -f "TEST-FIXED-autoinstall.iso" ]; then
    echo "✅ ISO corretto creato: TEST-FIXED-autoinstall.iso"
    ls -la "TEST-FIXED-autoinstall.iso"
else
    echo "❌ Creazione ISO fallita"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== TEST ISO CORRETTO ==="
echo "Sostituendo ISO FE_VM con versione corretta..."

# Stop FE_VM
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
sleep 3

# Sostituisci con ISO corretto
VMX_FILE="$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"
FIXED_ISO="$(pwd)/TEST-FIXED-autoinstall.iso"

sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$FIXED_ISO\"|" "$VMX_FILE"

echo "Nuovo ISO: $(grep 'ide1:0.fileName' "$VMX_FILE")"

# Riavvia con ISO corretto
echo "Riavviando FE_VM con ISO corretto..."
vmrun start "$VMX_FILE"

echo ""
echo "✅ FE_VM riavviata con GRUB corretto"
echo "🎯 DOVREBBE ORA BOOTARE AUTOMATICAMENTE SENZA ERRORI FONT!"
echo ""
echo "Osserva console FE_VM:"
echo "  • NO errori font"
echo "  • Boot automatico senza menu"
echo "  • Installazione Ubuntu automatica"

echo ""
echo "Se funziona, applicheremo questa configurazione a tutte le VM!"
