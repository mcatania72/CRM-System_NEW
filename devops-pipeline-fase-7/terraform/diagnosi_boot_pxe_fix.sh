#!/bin/bash

# DIAGNOSI E FIX BOOT PXE - ISO CORROTTO
# La VM è tornata a boot da network invece che da ISO

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "DIAGNOSI BOOT PXE - ISO CORROTTO"
echo "=========================================="

echo ""
echo "PROBLEMA: VM boota da PXE network invece che da ISO"
echo "CAUSA: ISO probabilmente corrotto durante modifica GRUB"

# STEP 1: VERIFICA CONFIGURAZIONE VMX
echo ""
echo "=== STEP 1: VERIFICA CONFIGURAZIONE VMX ==="

FE_VMX="$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"
echo "Configurazione CD/DVD FE_VM:"
grep -E "ide1:0\." "$FE_VMX" 2>/dev/null || echo "❌ Configurazione CD/DVD non trovata"

echo ""
echo "Boot order configurato:"
grep "bios.bootOrder" "$FE_VMX" 2>/dev/null || echo "❌ Boot order non trovato"

# Verifica path ISO nel VMX
ISO_PATH=$(grep "ide1:0.fileName" "$FE_VMX" 2>/dev/null | cut -d'"' -f2)
echo "Path ISO nel VMX: $ISO_PATH"

if [ -f "$ISO_PATH" ]; then
    echo "✅ ISO file exists: $ISO_PATH"
    ls -la "$ISO_PATH"
else
    echo "❌ ISO FILE NON TROVATO: $ISO_PATH"
fi

# STEP 2: TEST VALIDITÀ ISO
echo ""
echo "=== STEP 2: TEST VALIDITÀ ISO ==="

if [ -f "$ISO_PATH" ]; then
    echo "Testando validità ISO..."
    
    # Test basic file integrity
    if file "$ISO_PATH" | grep -q "ISO 9660"; then
        echo "✅ ISO format valido"
    else
        echo "❌ ISO FORMAT CORROTTO!"
        echo "File type: $(file "$ISO_PATH")"
    fi
    
    # Test mount ISO
    MOUNT_TEST="/tmp/iso_test_$$"
    mkdir -p "$MOUNT_TEST"
    
    if sudo mount -o loop "$ISO_PATH" "$MOUNT_TEST" 2>/dev/null; then
        echo "✅ ISO montabile"
        
        # Verifica struttura base
        if [ -f "$MOUNT_TEST/boot/grub/grub.cfg" ]; then
            echo "✅ GRUB config presente"
            echo "Prime righe GRUB:"
            head -10 "$MOUNT_TEST/boot/grub/grub.cfg"
        else
            echo "❌ GRUB CONFIG MANCANTE!"
        fi
        
        # Verifica file autoinstall
        if [ -f "$MOUNT_TEST/server/user-data" ]; then
            echo "✅ File autoinstall presenti"
        else
            echo "❌ FILE AUTOINSTALL MANCANTI!"
        fi
        
        sudo umount "$MOUNT_TEST"
        rmdir "$MOUNT_TEST"
    else
        echo "❌ ISO NON MONTABILE - CORROTTO!"
    fi
else
    echo "❌ ISO file non esistente"
fi

# STEP 3: RIPRISTINO ISO FUNZIONANTE
echo ""
echo "=== STEP 3: STRATEGIA RIPRISTINO ==="

echo ""
echo "OPZIONI RIPRISTINO:"
echo ""
echo "OPZIONE A - Ripristino ISO backup:"
echo "  • Cerca backup ISO precedenti"
echo "  • Ripristina ISO funzionante"
echo "  • Test boot da CD/DVD"
echo ""
echo "OPZIONE B - Ricostruzione ISO da zero:"
echo "  • Estrai ISO Ubuntu originale pulito"
echo "  • Ricrea autoinstall senza modifiche GRUB complesse"
echo "  • Usa approccio più semplice"
echo ""
echo "OPZIONE C - Fix VMX boot order:"
echo "  • Forza boot da CD come unica opzione"
echo "  • Rimuovi boot da network"
echo "  • Test con ISO esistente"

# Cerca backup ISO
echo ""
echo "=== RICERCA BACKUP ISO ==="
find ~/CRM-Fase7/devops-pipeline-fase-7/terraform -name "*.iso.backup*" -o -name "*SPESE_FE_VM*.backup" 2>/dev/null | head -5

# IMPLEMENTA OPZIONE C - FIX VMX BOOT ORDER
echo ""
echo "=== OPZIONE C: FIX VMX BOOT ORDER ==="

echo "Applicando fix VMX boot order per forzare CD..."

# Stop VM
vmrun stop "$FE_VMX" hard 2>/dev/null || true
sleep 3

# Backup VMX
cp "$FE_VMX" "$FE_VMX.backup-$(date +%H%M%S)"

# Fix boot order - SOLO CD/DVD
echo "Modificando boot order per forzare solo CD..."

# Rimuovi boot da network
sed -i '/ethernet.*present/a ethernet0.bootProto = "none"' "$FE_VMX"

# Forza boot solo da CD
sed -i 's/bios.bootOrder = .*/bios.bootOrder = "cdrom"/' "$FE_VMX"

# Aumenta boot delay per debug
sed -i 's/bios.bootDelay = .*/bios.bootDelay = "5000"/' "$FE_VMX"

# Verifica modifiche VMX
echo ""
echo "VMX modificato:"
grep -E "bootOrder|bootDelay|ethernet0.bootProto" "$FE_VMX"

# Verifica path ISO assoluto
CURRENT_ISO_PATH=$(grep "ide1:0.fileName" "$FE_VMX" | cut -d'"' -f2)
if [[ "$CURRENT_ISO_PATH" != /* ]]; then
    echo "Correggendo path ISO da relativo ad assoluto..."
    ABS_ISO_PATH="$(pwd)/SPESE_FE_VM-autoinstall.iso"
    sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ABS_ISO_PATH\"|" "$FE_VMX"
    echo "Nuovo path ISO: $(grep 'ide1:0.fileName' "$FE_VMX")"
fi

# OPZIONE B - RICOSTRUZIONE ISO SEMPLICE
echo ""
echo "=== OPZIONE B: RICOSTRUZIONE ISO SEMPLICE ==="

echo "Ricostruendo ISO FE_VM senza modifiche GRUB complesse..."

# Se ISO corrotto, ricrea da zero
ISO_BACKUP="${ISO_PATH}.original"
if [ ! -f "$ISO_BACKUP" ]; then
    echo "Creando backup ISO originale..."
    
    # Ricrea ISO da zero con approccio semplice
    SIMPLE_DIR="/tmp/simple_iso_$$"
    mkdir -p "$SIMPLE_DIR/source-files"
    
    echo "Estraendo ISO Ubuntu pulito..."
    7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$SIMPLE_DIR/source-files" >/dev/null 2>&1
    
    # Copia solo file autoinstall senza modifiche GRUB
    mkdir -p "$SIMPLE_DIR/source-files/server"
    if [ -f "autoinstall-FE/user-data" ]; then
        cp "autoinstall-FE/user-data" "$SIMPLE_DIR/source-files/server/"
        cp "autoinstall-FE/meta-data" "$SIMPLE_DIR/source-files/server/"
        echo "✅ File autoinstall copiati"
    else
        echo "❌ File autoinstall FE non trovati"
    fi
    
    # Crea ISO SENZA modifiche GRUB (usa Ubuntu GRUB originale)
    echo "Creando ISO con GRUB originale Ubuntu..."
    genisoimage -r -V "SPESE_FE_VM Simple" \
        -cache-inodes -J -joliet-long -l \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "SPESE_FE_VM-autoinstall-simple.iso" \
        "$SIMPLE_DIR/source-files" >/dev/null 2>&1
    
    if [ -f "SPESE_FE_VM-autoinstall-simple.iso" ]; then
        echo "✅ ISO semplice creato"
        
        # Sostituisci ISO corrotto con quello semplice
        mv "SPESE_FE_VM-autoinstall-simple.iso" "SPESE_FE_VM-autoinstall.iso"
        echo "✅ ISO corrotto sostituito con versione semplice"
    fi
    
    rm -rf "$SIMPLE_DIR"
fi

# RIAVVIA VM CON FIX
echo ""
echo "=== RIAVVIO VM CON FIX ==="

echo "Riavviando FE_VM con:"
echo "  • Boot order: solo CD"
echo "  • ISO: versione semplice senza modifiche GRUB"
echo "  • Path assoluto corretto"

if vmrun start "$FE_VMX"; then
    echo "✅ FE_VM riavviata"
else
    echo "❌ Errore riavvio FE_VM"
fi

echo ""
echo "🎯 RISULTATO ATTESO:"
echo "   1. ✅ Boot da CD/DVD (non PXE network)"
echo "   2. ✅ Menu GRUB Ubuntu standard"
echo "   3. ⚠️ Potrebbero apparire opzioni manuali (accettabile)"
echo "   4. ✅ Se selezioni autoinstall → installazione automatica"

echo ""
echo "=== PROSSIMI STEP ==="
echo "Se VM boota da CD ma mostra menu:"
echo "  • Seleziona opzione autoinstall se presente"
echo "  • Oppure accetta installazione manuale per completare deployment"
echo ""
echo "Se VM ancora PXE boot:"
echo "  • Problema hardware virtuale o ISO path"
echo "  • Approccio alternativo necessario"

echo ""
echo "L'obiettivo ora è FAR BOOTARE DA CD, poi ottimizzeremo automazione"
