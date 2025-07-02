#!/bin/bash

# FIX GRUB TIMEOUT PER AUTOINSTALL AUTOMATICO
# Il problema: GRUB timeout di 5 secondi mostra selezione lingua
# Soluzione: Timeout 1 secondo + boot automatico primo menu

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX GRUB TIMEOUT PER AUTOINSTALL AUTOMATICO ==="

# 1. INTERAZIONE MANUALE IMMEDIATA PER VM CORRENTI
echo "--- OPZIONE A: FIX IMMEDIATO VM CORRENTI ---"
echo "Se vuoi procedere subito con le VM attuali:"
echo "1. Apri console VMware di ogni VM"
echo "2. Premi ENTER per selezionare English (già evidenziato)"
echo "3. L'autoinstall partirà automaticamente"
echo ""
echo "VM da fixare manualmente:"
vmrun list | grep -v "Total"

echo ""
echo "--- OPZIONE B: RICOSTRUZIONE ISO CON GRUB AUTOMATICO ---"
echo "Per avere autoinstall completamente automatico in futuro"

# Backup ISO correnti
echo "Backup ISO correnti..."
for ISO in SPESE_*-autoinstall.iso; do
    if [ -f "$ISO" ]; then
        mv "$ISO" "$ISO.backup-$(date +%H%M%S)"
        echo "✅ Backup: $ISO"
    fi
done

# Ricostruzione ISO con GRUB timeout automatico
echo ""
echo "Ricostruendo ISO con GRUB automatico..."

# Script embedded per ricostruzione ISO
cat > fix_grub_timeout.sh << 'FIXSCRIPT'
#!/bin/bash

# Fix GRUB per ogni VM
for VM_TYPE in "FE" "BE" "DB"; do
    case $VM_TYPE in
        "FE") VM_NAME="SPESE_FE_VM"; IP="192.168.1.101" ;;
        "BE") VM_NAME="SPESE_BE_VM"; IP="192.168.1.102" ;;
        "DB") VM_NAME="SPESE_DB_VM"; IP="192.168.1.103" ;;
    esac
    
    echo "Creando ISO automatico per $VM_NAME..."
    
    # Directory temporanea
    TEMP_DIR="/tmp/autoinstall-fix-$VM_TYPE-$$"
    mkdir -p "$TEMP_DIR/source-files"
    
    # Estrai ISO Ubuntu
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$TEMP_DIR/source-files" >/dev/null
    
    # Crea directory autoinstall
    mkdir -p "$TEMP_DIR/source-files/server"
    
    # Copia file autoinstall
    cp "autoinstall-$VM_TYPE/user-data" "$TEMP_DIR/source-files/server/"
    cp "autoinstall-$VM_TYPE/meta-data" "$TEMP_DIR/source-files/server/"
    
    # MODIFICA GRUB PER BOOT AUTOMATICO (FIX PRINCIPALE)
    GRUB_CFG="$TEMP_DIR/source-files/boot/grub/grub.cfg"
    
    # Timeout 1 secondo + hidden menu + default autoinstall
    sed -i 's/timeout=30/timeout=1/' "$GRUB_CFG"
    sed -i 's/timeout_style=menu/timeout_style=hidden/' "$GRUB_CFG"
    
    # Aggiungi autoinstall come primo menu (default=0)
    sed -i "1s/^/set default=0\n/" "$GRUB_CFG"
    
    # Aggiungi menu autoinstall all'inizio
    sed -i "0,/menuentry \"Try or Install Ubuntu Server\"/s//menuentry \"Autoinstall $VM_NAME (AUTO)\" {\n\tset gfxpayload=keep\n\tlinux\t\/casper\/vmlinuz autoinstall ds=nocloud;s=\/cdrom\/server\/ quiet splash ---\n\tinitrd\t\/casper\/initrd\n}\n\nmenuentry \"Try or Install Ubuntu Server\"/" "$GRUB_CFG"
    
    # Crea ISO con genisoimage
    OUTPUT_ISO="$VM_NAME-autoinstall.iso"
    genisoimage -r -V "$VM_NAME Autoinstall AUTO" \
        -cache-inodes -J -joliet-long -l \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$OUTPUT_ISO" \
        "$TEMP_DIR/source-files" >/dev/null 2>&1
    
    if [ -f "$OUTPUT_ISO" ]; then
        echo "✅ ISO automatico creato: $OUTPUT_ISO"
    else
        echo "❌ Errore creazione ISO per $VM_NAME"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
done

echo "✅ Tutti gli ISO ricostruiti con GRUB automatico"
ls -la SPESE_*-autoinstall.iso
FIXSCRIPT

chmod +x fix_grub_timeout.sh

echo ""
echo "=== SCELTA STRATEGIA ==="
echo "OPZIONE A - Fix immediato (30 secondi):"
echo "  • 3 click ENTER nelle console VM"
echo "  • Installazione parte subito"
echo ""
echo "OPZIONE B - Ricostruzione automatica (5 minuti):"
echo "  • Esegui: ./fix_grub_timeout.sh"
echo "  • Stop VM attuali"
echo "  • Riavvia con ISO automatici"
echo ""
echo "RACCOMANDAZIONE: Opzione A per velocità, Opzione B per futuro"

echo ""
echo "=== STATUS VM ATTUALI ==="
vmrun list

echo ""
echo "Se scegli OPZIONE A:"
echo "1. Apri console VM in VMware Workstation"
echo "2. Clicca su ogni VM"
echo "3. Premi ENTER (English già selezionato)"
echo "4. Attendi installazione automatica (15-20 min)"
echo ""
echo "Se scegli OPZIONE B:"
echo "./fix_grub_timeout.sh"
