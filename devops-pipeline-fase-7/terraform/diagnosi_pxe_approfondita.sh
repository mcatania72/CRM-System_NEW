#!/bin/bash

# DIAGNOSI APPROFONDITA BOOT PXE - FIX HARDWARE VMX
# VM continua boot PXE nonostante fix precedenti

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "DIAGNOSI APPROFONDITA BOOT PXE"
echo "=========================================="

echo ""
echo "PROBLEMA PERSISTENTE: VM boota sempre da PXE network"
echo "CAUSE POSSIBILI:"
echo "1. CD/DVD drive non riconosciuto dal BIOS VM"
echo "2. ISO path errato o file corrotto"
echo "3. Boot order ignorato"
echo "4. Problema hardware virtuale VMX"

# STEP 1: DIAGNOSI VMX DETTAGLIATA
echo ""
echo "=== STEP 1: DIAGNOSI VMX DETTAGLIATA ==="

FE_VMX="$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"

if [ -f "$FE_VMX" ]; then
    echo "VMX trovato: $FE_VMX"
    
    echo ""
    echo "CONFIGURAZIONE CD/DVD COMPLETA:"
    grep -E "ide1|cdrom" "$FE_VMX" | cat -n
    
    echo ""
    echo "CONFIGURAZIONE BOOT:"
    grep -E "bios\.|boot" "$FE_VMX" | cat -n
    
    echo ""
    echo "CONFIGURAZIONE NETWORK:"
    grep -E "ethernet" "$FE_VMX" | cat -n
    
else
    echo "❌ VMX file non trovato: $FE_VMX"
    exit 1
fi

# STEP 2: VERIFICA ISO ESISTENZA E VALIDITÀ
echo ""
echo "=== STEP 2: VERIFICA ISO ==="

ISO_PATH=$(grep "ide1:0.fileName" "$FE_VMX" | cut -d'"' -f2)
echo "Path ISO configurato: $ISO_PATH"

if [ -f "$ISO_PATH" ]; then
    echo "✅ ISO file exists"
    ls -la "$ISO_PATH"
    
    # Test rapido ISO
    if file "$ISO_PATH" | grep -q "ISO 9660"; then
        echo "✅ ISO format valido"
    else
        echo "❌ ISO corrotto:"
        file "$ISO_PATH"
    fi
else
    echo "❌ ISO file NON ESISTE: $ISO_PATH"
    
    # Cerca ISO disponibili
    echo ""
    echo "ISO disponibili in directory corrente:"
    ls -la *.iso 2>/dev/null || echo "Nessun ISO trovato"
fi

# STEP 3: FIX HARDWARE VMX RADICALE
echo ""
echo "=== STEP 3: FIX HARDWARE VMX RADICALE ==="

echo "Applicando fix hardware VMX per forzare boot CD..."

# Stop VM
vmrun stop "$FE_VMX" hard 2>/dev/null || true
sleep 5

# Backup VMX
cp "$FE_VMX" "$FE_VMX.backup-emergency-$(date +%H%M%S)"

echo "Applicando configurazione VMX radicale..."

# CONFIGURAZIONE VMX RADICALE PER BOOT CD
cat >> "$FE_VMX" << 'VMXFIX'

# EMERGENCY CD BOOT CONFIGURATION
ide1:0.autodetect = "TRUE"
ide1:0.startConnected = "TRUE"
ide1:0.clientDevice = "FALSE"

# FORCE CD BOOT ONLY
bios.bootOrder = "cdrom"
bios.forceSetupOnce = "FALSE"
bios.bootDelay = "10000"

# DISABLE NETWORK BOOT
ethernet0.bootProto = "none"
ethernet0.startConnected = "FALSE"

# FORCE LEGACY BOOT
firmware = "bios"
boot.order = "ide1:0"

# CD/DVD PRIORITY
ide1:0.priority = "0"
VMXFIX

echo "✅ Configurazione VMX radicale applicata"

# STEP 4: VERIFICA/CORREGGI PATH ISO
echo ""
echo "=== STEP 4: VERIFICA PATH ISO ==="

# Se ISO non esiste al path configurato, usa ISO disponibile
if [ ! -f "$ISO_PATH" ]; then
    echo "ISO non trovato al path configurato, cercando alternative..."
    
    # Trova primo ISO disponibile
    AVAILABLE_ISO=$(ls *.iso 2>/dev/null | head -1)
    
    if [ ! -z "$AVAILABLE_ISO" ]; then
        ABS_ISO_PATH="$(pwd)/$AVAILABLE_ISO"
        echo "Usando ISO disponibile: $ABS_ISO_PATH"
        
        # Aggiorna path ISO nel VMX
        sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ABS_ISO_PATH\"|" "$FE_VMX"
        echo "✅ Path ISO aggiornato nel VMX"
    else
        echo "❌ Nessun ISO disponibile!"
        
        # Crea ISO minimal di test
        echo "Creando ISO minimal di test..."
        
        if [ -f "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" ]; then
            # Copia ISO Ubuntu originale come test
            cp "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" "ubuntu-test.iso"
            
            ABS_ISO_PATH="$(pwd)/ubuntu-test.iso"
            sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ABS_ISO_PATH\"|" "$FE_VMX"
            echo "✅ ISO test Ubuntu copiato e configurato"
        else
            echo "❌ ISO Ubuntu base non trovato"
        fi
    fi
fi

# STEP 5: CONFIGURAZIONE VMX FINALE
echo ""
echo "=== STEP 5: CONFIGURAZIONE VMX FINALE ==="

echo "Configurazione finale VMX:"
echo ""
echo "CD/DVD:"
grep -E "ide1:0\." "$FE_VMX" | tail -10

echo ""
echo "Boot:"
grep -E "bios\.|boot|firmware" "$FE_VMX" | tail -10

echo ""
echo "Network:"
grep -E "ethernet0\." "$FE_VMX" | tail -5

# STEP 6: TEST BOOT
echo ""
echo "=== STEP 6: TEST BOOT ==="

echo "Avviando VM con configurazione radicale..."

if vmrun start "$FE_VMX"; then
    echo "✅ VM avviata"
    
    echo ""
    echo "🎯 VERIFICA BOOT:"
    echo "   1. VM dovrebbe tentare boot da CD per primi 10 secondi"
    echo "   2. Network boot dovrebbe essere disabilitato"
    echo "   3. Se ancora PXE, problema più profondo"
    
    echo ""
    echo "=== MONITORING BOOT ==="
    echo "Attendi 30 secondi e controlla console VM..."
    
    sleep 30
    
    echo ""
    echo "Se VM ancora in PXE boot:"
    echo "  • Problema VMware Workstation settings"
    echo "  • ISO completamente corrotto"
    echo "  • Hardware virtuale non funzionante"
    
else
    echo "❌ Errore avvio VM"
    echo "VMX potrebbe essere corrotto"
fi

# STEP 7: PIANO B - RICOSTRUZIONE VM
echo ""
echo "=== STEP 7: PIANO B - RICOSTRUZIONE VM ==="

echo ""
echo "Se VM ancora non boota da CD, PIANO B:"
echo ""
echo "1. DISTRUZIONE E RICOSTRUZIONE VM:"
echo "   vmrun deleteVM '$FE_VMX'"
echo "   Ricreare VM da zero con Terraform"
echo ""
echo "2. TEST CON ISO UBUNTU BASE:"
echo "   Usa ISO Ubuntu originale per test boot"
echo "   Se boota, problema con ISO autoinstall"
echo ""
echo "3. VERIFICA VMWARE WORKSTATION:"
echo "   Settings globali VMware"
echo "   CD/DVD drive settings"

echo ""
echo "=== STATUS ATTUALE ==="
echo "VM configurata con:"
echo "  • Boot order: solo CD"
echo "  • Network boot: disabilitato"
echo "  • Boot delay: 10 secondi"
echo "  • CD autodetect: attivo"

echo ""
echo "🎯 SE ANCORA PXE BOOT → PROBLEMA VMWARE WORKSTATION"
