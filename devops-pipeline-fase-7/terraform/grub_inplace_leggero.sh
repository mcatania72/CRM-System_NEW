#!/bin/bash

# APPROCCIO LEGGERO - MODIFICA GRUB IN-PLACE
# Strategia: modifica ISO esistenti senza creare copie multiple

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== APPROCCIO LEGGERO - MODIFICA GRUB IN-PLACE ==="
echo "Obiettivo: autoinstall automatico senza sprecare spazio disco"

# Verifica spazio disco attuale
echo ""
echo "=== SPAZIO DISCO ATTUALE ==="
df -h /

echo ""
echo "=== ISO DISPONIBILI ==="
ls -la *.iso

# Test con UN SOLO ISO (FE_VM) per verificare strategia
echo ""
echo "=== MODIFICA GRUB FE_VM ISO ==="

# Stop FE_VM per sicurezza
echo "Fermando FE_VM..."
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
sleep 3

# Modifica GRUB direttamente nell'ISO esistente
ISO_FILE="SPESE_FE_VM-autoinstall.iso"

if [ ! -f "$ISO_FILE" ]; then
    echo "❌ $ISO_FILE non trovato"
    exit 1
fi

WORK_DIR="/tmp/grub_inplace_$$"
mkdir -p "$WORK_DIR"

echo "Estraendo $ISO_FILE per modifica GRUB..."
7z -y x "$ISO_FILE" -o"$WORK_DIR" >/dev/null 2>&1

if [ ! -d "$WORK_DIR/boot/grub" ]; then
    echo "❌ Struttura GRUB non trovata nell'ISO"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Backup GRUB originale
cp "$WORK_DIR/boot/grub/grub.cfg" "$WORK_DIR/boot/grub/grub.cfg.backup"

echo "✅ ISO estratto, modificando GRUB..."

# Modifica GRUB con approccio minimale e sicuro
GRUB_CFG="$WORK_DIR/boot/grub/grub.cfg"

echo ""
echo "GRUB ORIGINALE (prime 10 righe):"
head -10 "$GRUB_CFG"

echo ""
echo "Applicando modifiche GRUB minimali..."

# STRATEGIA SICURA: modifica solo parametri essenziali
# 1. Cambia timeout esistente a 0
# 2. Aggiungi timeout_style=hidden
# 3. Imposta default=0
# 4. Modifica primo menuentry per autoinstall

# Trova e modifica timeout
if grep -q "set timeout=" "$GRUB_CFG"; then
    sed -i 's/set timeout=.*/set timeout=0/' "$GRUB_CFG"
    echo "✅ Timeout modificato a 0"
else
    # Aggiungi timeout all'inizio
    sed -i '1i set timeout=0' "$GRUB_CFG"
    echo "✅ Timeout=0 aggiunto"
fi

# Aggiungi timeout_style=hidden se non presente
if ! grep -q "timeout_style" "$GRUB_CFG"; then
    sed -i '/set timeout=0/a set timeout_style=hidden' "$GRUB_CFG"
    echo "✅ timeout_style=hidden aggiunto"
fi

# Aggiungi/modifica default=0
if grep -q "set default=" "$GRUB_CFG"; then
    sed -i 's/set default=.*/set default=0/' "$GRUB_CFG"
    echo "✅ Default modificato a 0"
else
    sed -i '/timeout_style=hidden/a set default=0' "$GRUB_CFG"
    echo "✅ Default=0 aggiunto"
fi

# Trova primo menuentry e modifica per autoinstall
FIRST_MENU_LINE=$(grep -n "menuentry" "$GRUB_CFG" | head -1 | cut -d: -f1)

if [ ! -z "$FIRST_MENU_LINE" ]; then
    echo "Modificando primo menuentry (riga $FIRST_MENU_LINE) per autoinstall..."
    
    # Modifica titolo menuentry
    sed -i "${FIRST_MENU_LINE}s/.*/menuentry \"Ubuntu Autoinstall - FE_VM (AUTO)\" {/" "$GRUB_CFG"
    
    # Trova riga linux e modifica per autoinstall
    LINUX_LINE_START=$((FIRST_MENU_LINE + 1))
    LINUX_LINE_END=$((FIRST_MENU_LINE + 5))
    
    # Cerca riga linux nel range del primo menu
    for i in $(seq $LINUX_LINE_START $LINUX_LINE_END); do
        if sed -n "${i}p" "$GRUB_CFG" | grep -q "linux.*vmlinuz"; then
            echo "Modificando riga linux $i per autoinstall..."
            sed -i "${i}s/.*/\tlinux\t\/casper\/vmlinuz autoinstall ds=nocloud;s=\/cdrom\/server\/ quiet splash ---/" "$GRUB_CFG"
            echo "✅ Parametri autoinstall applicati"
            break
        fi
    done
else
    echo "❌ Nessun menuentry trovato"
fi

echo ""
echo "GRUB MODIFICATO (prime 20 righe):"
head -20 "$GRUB_CFG"

echo ""
echo "Ricostruendo ISO con GRUB modificato..."

# Ricostruisci ISO (sovrascrive quello esistente)
ISO_TEMP="${ISO_FILE}.temp"
genisoimage -r -V "SPESE_FE_VM Auto" \
    -cache-inodes -J -joliet-long -l \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "$ISO_TEMP" \
    "$WORK_DIR" >/dev/null 2>&1

if [ -f "$ISO_TEMP" ]; then
    # Sostituisci ISO originale con quello modificato
    mv "$ISO_TEMP" "$ISO_FILE"
    echo "✅ $ISO_FILE aggiornato con GRUB automatico"
    ls -la "$ISO_FILE"
else
    echo "❌ Errore ricostruzione ISO"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Cleanup
rm -rf "$WORK_DIR"

echo ""
echo "=== TEST FE_VM CON GRUB AUTOMATICO ==="

# Riavvia FE_VM con ISO modificato
echo "Riavviando FE_VM con ISO automatico..."
if vmrun start "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"; then
    echo "✅ FE_VM riavviata con GRUB automatico"
else
    echo "❌ Errore avvio FE_VM"
fi

echo ""
echo "🎯 RISULTATO ATTESO:"
echo "   1. ❌ NO selezione lingua"
echo "   2. ✅ Boot automatico immediato (timeout=0)"
echo "   3. ✅ Installazione Ubuntu automatica"
echo "   4. ✅ ZERO intervento manuale"

echo ""
echo "=== PROSSIMI STEP ==="
echo "Se FE_VM boota automaticamente:"
echo "  1. Applica stessa modifica a BE_VM ISO"
echo "  2. Applica stessa modifica a DB_VM ISO"
echo "  3. Deployment completamente automatico"
echo ""
echo "Se FE_VM ancora bloccato:"
echo "  1. Analizza console per errori specifici"
echo "  2. Verifica GRUB modificato"
echo "  3. Approccio alternativo"

echo ""
echo "=== MONITORAGGIO CONSIGLIATO ==="
echo "Controlla console FE_VM per 2-3 minuti"
echo "Se non parte automaticamente, segnala errori specifici"

echo ""
echo "=== SPAZIO DISCO FINALE ==="
df -h /
echo "ISO modificato in-place - nessuno spazio aggiuntivo utilizzato"
