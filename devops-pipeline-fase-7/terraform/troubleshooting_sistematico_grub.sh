#!/bin/bash

# TROUBLESHOOTING SISTEMATICO E RICOSTRUZIONE GRUB CORRETTA
# OBIETTIVO: AUTOINSTALL COMPLETAMENTE AUTOMATICO PER PRODUZIONE

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "========================================"
echo "TROUBLESHOOTING SISTEMATICO GRUB"
echo "========================================"

echo ""
echo "🎯 OBIETTIVO: ZERO TOUCH DEPLOYMENT PER PRODUZIONE"
echo "❌ APPROCCI FALLITI:"
echo "   - Modifica timeout esistente"
echo "   - Sostituzione completa GRUB config"
echo "   - Inserimento menu personalizzati"
echo ""
echo "✅ APPROCCIO CORRETTO: ANALISI E RICOSTRUZIONE METODICA"

# STEP 1: ANALISI STRUTTURA GRUB UBUNTU ORIGINALE
echo ""
echo "=== STEP 1: ANALISI STRUTTURA GRUB UBUNTU ==="

MOUNT_DIR="/tmp/grub_analysis_detailed_$$"
mkdir -p "$MOUNT_DIR"

if sudo mount -o loop "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" "$MOUNT_DIR" 2>/dev/null; then
    echo "✅ ISO Ubuntu originale montato per analisi dettagliata"
    
    # Analizza struttura completa GRUB
    echo ""
    echo "STRUTTURA GRUB COMPLETA:"
    find "$MOUNT_DIR/boot/grub" -type f | head -10
    
    echo ""
    echo "GRUB CONFIG ORIGINALE (prime 30 righe):"
    head -30 "$MOUNT_DIR/boot/grub/grub.cfg"
    
    echo ""
    echo "TIMEOUT E MENU CONFIGURATION:"
    grep -E "timeout|default|menuentry" "$MOUNT_DIR/boot/grub/grub.cfg" | head -10
    
    echo ""
    echo "KERNEL BOOT PARAMETERS:"
    grep -A 2 -B 2 "vmlinuz" "$MOUNT_DIR/boot/grub/grub.cfg" | head -10
    
    # Salva GRUB originale per riferimento
    cp "$MOUNT_DIR/boot/grub/grub.cfg" "/tmp/grub_original.cfg"
    echo "✅ GRUB originale salvato in /tmp/grub_original.cfg"
    
    sudo umount "$MOUNT_DIR"
    rmdir "$MOUNT_DIR"
else
    echo "❌ Impossibile montare ISO originale"
    exit 1
fi

# STEP 2: IDENTIFICAZIONE PROBLEMA AUTOINSTALL
echo ""
echo "=== STEP 2: IDENTIFICAZIONE PROBLEMA AUTOINSTALL ==="

echo ""
echo "ANALISI PROBLEMA:"
echo "1. Ubuntu autoinstall richiede parametro kernel 'autoinstall'"
echo "2. GRUB deve passare parametro senza mostrare menu"
echo "3. Datasource cloud-init deve essere trovato (ds=nocloud;s=/cdrom/server/)"
echo "4. Timeout GRUB deve essere configurato per boot automatico"

echo ""
echo "VERIFICA PARAMETRI AUTOINSTALL ESISTENTI:"
for ISO in SPESE_*-autoinstall.iso; do
    if [ -f "$ISO" ]; then
        echo ""
        echo "--- $ISO ---"
        TEMP_MOUNT="/tmp/check_$$"
        mkdir -p "$TEMP_MOUNT"
        
        if sudo mount -o loop "$ISO" "$TEMP_MOUNT" 2>/dev/null; then
            echo "Parametri autoinstall trovati:"
            grep -n "autoinstall" "$TEMP_MOUNT/boot/grub/grub.cfg" || echo "❌ AUTOINSTALL NON TROVATO"
            
            echo "Configurazione datasource:"
            grep -n "ds=nocloud" "$TEMP_MOUNT/boot/grub/grub.cfg" || echo "❌ DATASOURCE NON TROVATO"
            
            echo "File user-data:"
            if [ -f "$TEMP_MOUNT/server/user-data" ]; then
                echo "✅ user-data presente ($(wc -l < "$TEMP_MOUNT/server/user-data") righe)"
            else
                echo "❌ user-data MANCANTE"
            fi
            
            sudo umount "$TEMP_MOUNT"
        fi
        rmdir "$TEMP_MOUNT"
    fi
done

# STEP 3: RICOSTRUZIONE GRUB METODICA
echo ""
echo "=== STEP 3: RICOSTRUZIONE GRUB METODICA ==="

echo ""
echo "STRATEGIA CORRETTA:"
echo "1. Usa GRUB originale Ubuntu come base"
echo "2. Modifica SOLO i parametri necessari per autoinstall"
echo "3. Mantieni TUTTI i path, font, e configurazioni originali"
echo "4. Aggiungi autoinstall come PRIMO menu entry"
echo "5. Imposta timeout=0 per boot immediato"

echo ""
echo "Creando ISO con GRUB metodicamente corretto..."

# Creazione ISO con approccio metodico
for VM_TYPE in "FE" "BE" "DB"; do
    case $VM_TYPE in
        "FE") VM_NAME="SPESE_FE_VM"; IP="192.168.1.101" ;;
        "BE") VM_NAME="SPESE_BE_VM"; IP="192.168.1.102" ;;
        "DB") VM_NAME="SPESE_DB_VM"; IP="192.168.1.103" ;;
    esac
    
    echo ""
    echo "--- RICOSTRUZIONE METODICA $VM_NAME ---"
    
    TEMP_DIR="/tmp/grub_methodical_${VM_TYPE}_$$"
    mkdir -p "$TEMP_DIR/source-files"
    
    # Estrai ISO Ubuntu PULITO
    echo "Estraendo ISO Ubuntu pulito..."
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$TEMP_DIR/source-files" >/dev/null 2>&1
    
    # Crea file autoinstall
    mkdir -p "$TEMP_DIR/source-files/server"
    cp "autoinstall-$VM_TYPE/user-data" "$TEMP_DIR/source-files/server/"
    cp "autoinstall-$VM_TYPE/meta-data" "$TEMP_DIR/source-files/server/"
    
    echo "✅ File autoinstall copiati"
    
    # RICOSTRUZIONE GRUB METODICA
    GRUB_CFG="$TEMP_DIR/source-files/boot/grub/grub.cfg"
    GRUB_NEW="$TEMP_DIR/grub_new.cfg"
    
    echo "Ricostruendo GRUB metodicamente..."
    
    # Inizia con header originale (fino a primo menuentry)
    sed '/^menuentry/,$d' "$GRUB_CFG" > "$GRUB_NEW"
    
    # Aggiungi configurazione autoinstall
    cat >> "$GRUB_NEW" << AUTOGRUB

# AUTOINSTALL CONFIGURATION - PRODUCTION ZERO-TOUCH
set timeout=0
set timeout_style=hidden
set default=0

# AUTOINSTALL ENTRY - AUTOMATIC BOOT
menuentry "Ubuntu Server Autoinstall - $VM_NAME" {
	set gfxpayload=keep
	linux	/casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/server/ quiet splash ---
	initrd	/casper/initrd
}

AUTOGRUB
    
    # Aggiungi menu originali come backup
    sed -n '/^menuentry/,$p' "$GRUB_CFG" >> "$GRUB_NEW"
    
    # Sostituisci GRUB
    cp "$GRUB_NEW" "$GRUB_CFG"
    
    echo "✅ GRUB ricostruito metodicamente"
    
    # Verifica GRUB finale
    echo "GRUB finale (prime 25 righe):"
    head -25 "$GRUB_CFG"
    
    # Crea ISO
    OUTPUT_ISO="${VM_NAME}-METHODICAL-autoinstall.iso"
    echo ""
    echo "Creando $OUTPUT_ISO..."
    
    genisoimage -r -V "$VM_NAME Methodical" \
        -cache-inodes -J -joliet-long -l \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$OUTPUT_ISO" \
        "$TEMP_DIR/source-files" >/dev/null 2>&1
    
    if [ -f "$OUTPUT_ISO" ]; then
        echo "✅ $OUTPUT_ISO creato con successo"
        ls -la "$OUTPUT_ISO"
    else
        echo "❌ Creazione $OUTPUT_ISO fallita"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
done

echo ""
echo "=== STEP 4: TEST ISO METODICI ==="

echo ""
echo "ISO METODICI CREATI:"
ls -la SPESE_*-METHODICAL-autoinstall.iso

echo ""
echo "TEST CON FE_VM:"
echo "1. Stop FE_VM corrente"
echo "2. Sostituisci con ISO metodico"
echo "3. Verifica boot automatico SENZA errori GRUB"

# Test automatico con FE_VM
echo ""
echo "Testando ISO metodico con FE_VM..."

# Stop FE_VM
vmrun stop "$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx" hard 2>/dev/null || true
sleep 3

# Sostituisci con ISO metodico
VMX_FILE="$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"
METHODICAL_ISO="$(pwd)/SPESE_FE_VM-METHODICAL-autoinstall.iso"

if [ -f "$METHODICAL_ISO" ]; then
    echo "Sostituendo con ISO metodico..."
    sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$METHODICAL_ISO\"|" "$VMX_FILE"
    
    echo "Nuovo ISO: $(grep 'ide1:0.fileName' "$VMX_FILE")"
    
    # Riavvia
    echo "Riavviando FE_VM con ISO metodico..."
    vmrun start "$VMX_FILE"
    
    echo ""
    echo "✅ FE_VM riavviata con GRUB metodico"
    echo ""
    echo "🎯 VERIFICA RISULTATO:"
    echo "   - NO errori GRUB"
    echo "   - Boot immediato senza menu"
    echo "   - Installazione Ubuntu automatica"
    echo "   - ZERO intervento manuale richiesto"
    
else
    echo "❌ ISO metodico non trovato"
fi

echo ""
echo "========================================"
echo "🎯 APPROCCIO METODICO COMPLETATO"
echo "========================================"
echo ""
echo "Se FE_VM boota automaticamente:"
echo "1. Applicheremo ISO metodici a BE e DB"
echo "2. Deployment completamente automatico"
echo "3. PRODUZIONE-READY zero-touch"
echo ""
echo "Se ancora problemi:"
echo "1. Analizzeremo GRUB metodico"
echo "2. Identificheremo specifici errori"
echo "3. Correggeremo metodicamente"
echo ""
echo "OBIETTIVO: AUTOINSTALL PERFETTO PER PRODUZIONE!"
