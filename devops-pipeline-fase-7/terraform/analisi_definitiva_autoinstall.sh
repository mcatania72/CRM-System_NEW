#!/bin/bash

# ANALISI COMPLETA E DEFINITIVA PROBLEMA AUTOINSTALL
# Root cause analysis per selezione lingua bloccata

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "ANALISI DEFINITIVA PROBLEMA AUTOINSTALL"
echo "=========================================="

# STEP 1: VERIFICA CONFIGURAZIONE GRUB NEGLI ISO
echo ""
echo "=== STEP 1: ANALISI GRUB CONFIGURATION ==="

for ISO in SPESE_*-autoinstall.iso; do
    if [ -f "$ISO" ]; then
        echo ""
        echo "--- ANALISI $ISO ---"
        
        # Mount ISO per analisi
        MOUNT_DIR="/tmp/grub_analysis_$$"
        mkdir -p "$MOUNT_DIR"
        
        if sudo mount -o loop "$ISO" "$MOUNT_DIR" 2>/dev/null; then
            echo "✅ ISO montato per analisi"
            
            # Analizza GRUB config
            if [ -f "$MOUNT_DIR/boot/grub/grub.cfg" ]; then
                echo "GRUB Configuration trovata:"
                echo "  Timeout: $(grep -E '^set timeout=' "$MOUNT_DIR/boot/grub/grub.cfg" || echo 'NON TROVATO')"
                echo "  Timeout style: $(grep -E '^set timeout_style=' "$MOUNT_DIR/boot/grub/grub.cfg" || echo 'NON TROVATO')"
                echo "  Default: $(grep -E '^set default=' "$MOUNT_DIR/boot/grub/grub.cfg" || echo 'NON TROVATO')"
                
                echo "Menu entries:"
                grep -A 2 "menuentry" "$MOUNT_DIR/boot/grub/grub.cfg" | head -10
                
                echo "Autoinstall parameters:"
                grep -n "autoinstall" "$MOUNT_DIR/boot/grub/grub.cfg" || echo "❌ AUTOINSTALL NON TROVATO IN GRUB"
                
            else
                echo "❌ GRUB config non trovato"
            fi
            
            # Verifica file autoinstall
            echo "File autoinstall presenti:"
            find "$MOUNT_DIR" -name "user-data" -o -name "meta-data" | while read file; do
                echo "  ✅ $file ($(wc -l < "$file") righe)"
            done
            
            sudo umount "$MOUNT_DIR"
            rmdir "$MOUNT_DIR"
        else
            echo "❌ Impossibile montare ISO: $ISO"
        fi
    fi
done

# STEP 2: VERIFICA AUTOINSTALL USER-DATA
echo ""
echo "=== STEP 2: ANALISI USER-DATA AUTOINSTALL ==="

for DIR in autoinstall-*; do
    if [ -d "$DIR" ]; then
        echo ""
        echo "--- ANALISI $DIR ---"
        
        if [ -f "$DIR/user-data" ]; then
            echo "User-data configuration:"
            echo "  Version: $(grep -E '^  version:' "$DIR/user-data" || echo 'NON TROVATO')"
            echo "  Locale: $(grep -E '^  locale:' "$DIR/user-data" || echo 'NON TROVATO')"
            echo "  Interactive: $(grep -E 'interactive' "$DIR/user-data" || echo 'NON SPECIFICATO')"
            
            # Verifica configurazione critica
            if grep -q "autoinstall:" "$DIR/user-data"; then
                echo "  ✅ Sezione autoinstall presente"
            else
                echo "  ❌ SEZIONE AUTOINSTALL MANCANTE!"
            fi
            
            # Verifica interactive mode (potrebbe causare prompt lingua)
            if grep -q "interactive:" "$DIR/user-data"; then
                echo "  ⚠️ Interactive mode specificato:"
                grep -A 2 -B 2 "interactive" "$DIR/user-data"
            fi
            
        else
            echo "❌ user-data non trovato in $DIR"
        fi
    fi
done

# STEP 3: TEST BOOT PARAMETERS
echo ""
echo "=== STEP 3: ANALISI BOOT PARAMETERS ==="

echo "Verifica che GRUB passi parametri corretti per autoinstall..."

# Crea ISO test con configurazione corretta
echo "Creando ISO test con configurazione GRUB ottimizzata..."

VM_NAME="TEST_AUTOINSTALL"
TEMP_DIR="/tmp/grub_test_$$"
mkdir -p "$TEMP_DIR/source-files"

# Estrai ISO base
echo "Estraendo ISO Ubuntu base..."
7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$TEMP_DIR/source-files" >/dev/null

# Crea user-data ottimizzato
mkdir -p "$TEMP_DIR/source-files/server"
cat > "$TEMP_DIR/source-files/server/user-data" << 'EOF'
#cloud-config
autoinstall:
  version: 1
  early-commands:
    - systemctl stop ssh
  locale: en_US.UTF-8
  keyboard:
    layout: us
    variant: ''
  network:
    version: 2
    ethernets:
      ens33:
        dhcp4: true
  identity:
    hostname: test-autoinstall
    username: devops
    password: '$6$rounds=4096$saltsalt$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm'
    realname: 'DevOps User'
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
# CRITICAL: No interactive sections that could pause installation
EOF

cat > "$TEMP_DIR/source-files/server/meta-data" << 'EOF'
instance-id: test-autoinstall
local-hostname: test-autoinstall
EOF

# GRUB configuration ottimizzata
GRUB_CFG="$TEMP_DIR/source-files/boot/grub/grub.cfg"

# BACKUP grub originale
cp "$GRUB_CFG" "$GRUB_CFG.original"

# CONFIGURAZIONE GRUB OTTIMIZZATA
cat > "$GRUB_CFG" << 'GRUBEOF'
if loadfont /boot/grub/font.pf2 ; then
    set gfxmode=auto
    insmod efi_gop
    insmod efi_uga
    insmod gfxterm
    terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

# AUTOINSTALL CONFIGURATION - NO INTERACTION
set timeout=0
set timeout_style=hidden
set default=0

# AUTOINSTALL ENTRY - COMPLETELY AUTOMATIC
menuentry "Ubuntu Server Autoinstall (AUTOMATIC)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/server/ quiet splash ---
    initrd  /casper/initrd
}

# MANUAL ENTRIES (NOT USED)
menuentry "Try or Install Ubuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz  ---
    initrd  /casper/initrd
}

menuentry "Ubuntu Server with the HWE kernel" {
    set gfxpayload=keep
    linux   /casper/vmlinuz-hwe  ---
    initrd  /casper/initrd-hwe
}
GRUBEOF

echo "✅ GRUB ottimizzato creato"
echo "Configurazione GRUB test:"
echo "  - timeout=0 (boot immediato)"
echo "  - timeout_style=hidden (no menu visibile)"
echo "  - default=0 (primo entry = autoinstall)"
echo "  - parametri: autoinstall ds=nocloud;s=/cdrom/server/ quiet splash"

# Crea ISO test
echo "Creando ISO test..."
genisoimage -r -V "Ubuntu Test Autoinstall" \
    -cache-inodes -J -joliet-long -l \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "TEST-autoinstall.iso" \
    "$TEMP_DIR/source-files" >/dev/null 2>&1

if [ -f "TEST-autoinstall.iso" ]; then
    echo "✅ ISO test creato: TEST-autoinstall.iso"
    ls -la "TEST-autoinstall.iso"
else
    echo "❌ Creazione ISO test fallita"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== STEP 4: CONFRONTO CONFIGURAZIONI ==="

echo "Differenze identificate:"
echo "1. TIMEOUT: I nostri ISO potrebbero avere timeout > 0"
echo "2. TIMEOUT_STYLE: Potrebbe essere 'menu' invece di 'hidden'"
echo "3. DEFAULT: Potrebbe non essere impostato a 0"
echo "4. BOOT PARAMS: Parametri autoinstall potrebbero essere incompleti"

echo ""
echo "=== RACCOMANDAZIONI FINALI ==="
echo ""
echo "OPZIONE 1 - Test ISO ottimizzato:"
echo "  • Sostituisci uno degli ISO correnti con TEST-autoinstall.iso"
echo "  • Verifica se boota automaticamente"
echo "  • Se funziona, applica stessa config a tutti gli ISO"
echo ""
echo "OPZIONE 2 - Fix manuale immediato:"
echo "  • 3 click ENTER per procedere con installazione"
echo "  • Completa deployment corrente"
echo "  • Fix GRUB per future VM"
echo ""
echo "OPZIONE 3 - Ricostruzione completa:"
echo "  • Applica configurazione GRUB ottimizzata a tutti gli ISO"
echo "  • Riavvia tutte le VM"
echo "  • Autoinstall completamente automatico"

echo ""
echo "=== ANALISI COMPLETATA ==="
echo "Risultati disponibili per decisione strategica"
