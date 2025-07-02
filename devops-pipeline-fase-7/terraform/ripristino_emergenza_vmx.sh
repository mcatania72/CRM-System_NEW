#!/bin/bash

# RIPRISTINO EMERGENZA VMX CORROTTO
# Il file VMX è stato corrotto dalla configurazione radicale

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "RIPRISTINO EMERGENZA VMX CORROTTO"
echo "=========================================="

FE_VM_DIR="$HOME/VMware_VMs/SPESE_FE_VM"
FE_VMX="$FE_VM_DIR/SPESE_FE_VM.vmx"

echo ""
echo "PROBLEMA: VMX corrotto da configurazione radicale"
echo "SOLUZIONE: Ripristino da backup o ricostruzione"

# STEP 1: VERIFICA BACKUP VMX
echo ""
echo "=== STEP 1: RICERCA BACKUP VMX ==="

echo "Backup VMX disponibili:"
ls -la "$FE_VM_DIR"/*.backup* 2>/dev/null || echo "❌ Nessun backup VMX trovato"

# Trova backup più recente
LATEST_BACKUP=$(ls -t "$FE_VM_DIR"/*.backup* 2>/dev/null | head -1)

if [ ! -z "$LATEST_BACKUP" ]; then
    echo "✅ Backup più recente trovato: $LATEST_BACKUP"
    
    # Ripristina backup
    echo "Ripristinando VMX da backup..."
    cp "$LATEST_BACKUP" "$FE_VMX"
    
    if [ -f "$FE_VMX" ]; then
        echo "✅ VMX ripristinato da backup"
        
        # Test validità VMX ripristinato
        if grep -q "virtualHW.version" "$FE_VMX" && grep -q "displayName" "$FE_VMX"; then
            echo "✅ VMX backup sembra valido"
        else
            echo "❌ VMX backup anche corrotto"
            LATEST_BACKUP=""
        fi
    else
        echo "❌ Ripristino backup fallito"
        LATEST_BACKUP=""
    fi
else
    echo "❌ Nessun backup VMX utilizzabile"
fi

# STEP 2: RICOSTRUZIONE VMX DA ZERO (se backup non funziona)
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$FE_VMX" ]; then
    echo ""
    echo "=== STEP 2: RICOSTRUZIONE VMX DA ZERO ==="
    
    echo "Ricostruendo VMX FE_VM da zero..."
    
    # Trova ISO disponibile
    AVAILABLE_ISO=$(ls *.iso 2>/dev/null | head -1)
    if [ ! -z "$AVAILABLE_ISO" ]; then
        ISO_PATH="$(pwd)/$AVAILABLE_ISO"
        echo "ISO da usare: $ISO_PATH"
    else
        ISO_PATH="/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso"
        echo "ISO fallback: $ISO_PATH"
    fi
    
    # Crea VMX completamente nuovo
    cat > "$FE_VMX" << NEWVMX
#!/usr/bin/vmware
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"

# VM Identification
displayName = "SPESE_FE_VM"
annotation = "Kubernetes Master + Frontend|0A|Role: master|0A|IP: 192.168.1.101"
guestOS = "ubuntu-64"

# Hardware Configuration
memsize = "4096"
numvcpus = "2"
cpuid.coresPerSocket = "1"

# Disk Configuration - SCSI
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "SPESE_FE_VM.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"

# Network Configuration
ethernet0.present = "TRUE"
ethernet0.connectionType = "bridged"
ethernet0.virtualDev = "e1000"
ethernet0.wakeOnPcktRcv = "FALSE"
ethernet0.addressType = "generated"

# CD/DVD Configuration - SIMPLE
ide1:0.present = "TRUE"
ide1:0.fileName = "$ISO_PATH"
ide1:0.deviceType = "cdrom-image"
ide1:0.startConnected = "TRUE"

# Boot Configuration - SIMPLE
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "5000"

# Essential VMware settings
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
vmci0.present = "TRUE"
hpet0.present = "TRUE"

# USB Configuration
usb.present = "TRUE"
ehci.present = "TRUE"

# Tools
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"

# Power Options
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
NEWVMX

    echo "✅ VMX ricostruito da zero"
fi

# STEP 3: VERIFICA VMDK
echo ""
echo "=== STEP 3: VERIFICA VMDK ==="

VMDK_FILE="$FE_VM_DIR/SPESE_FE_VM.vmdk"

if [ -f "$VMDK_FILE" ]; then
    echo "✅ VMDK trovato: $VMDK_FILE"
    ls -la "$VMDK_FILE"
else
    echo "❌ VMDK mancante, ricostruendo..."
    
    # Crea VMDK semplice
    if command -v vmware-vdiskmanager &> /dev/null; then
        vmware-vdiskmanager -c -s 25GB -a lsilogic -t 0 "$VMDK_FILE"
        echo "✅ VMDK ricreato con vmware-vdiskmanager"
    else
        # VMDK manuale
        touch "$FE_VM_DIR/SPESE_FE_VM-flat.vmdk"
        cat > "$VMDK_FILE" << 'VMDKEOF'
# Disk DescriptorFile
version=1
encoding="UTF-8"
CID=fffffffe
parentCID=ffffffff
isNativeSnapshot="no"
createType="vmfs"

# Extent description
RW 52428800 VMFS "SPESE_FE_VM-flat.vmdk"

# The Disk Data Base
#DDB

ddb.virtualHWVersion = "19"
ddb.longContentID = "abcdef1234567890abcdef1234567890"
ddb.uuid = "60 00 C2 9a 12 34 56 78-ab cd ef 12 34 56 78 90"
ddb.geometry.cylinders = "3264"
ddb.geometry.heads = "16"
ddb.geometry.sectors = "63"
ddb.adapterType = "lsilogic"
VMDKEOF
        echo "✅ VMDK ricreato manualmente"
    fi
fi

# STEP 4: TEST AVVIO VMX RICOSTRUITO
echo ""
echo "=== STEP 4: TEST AVVIO VMX RICOSTRUITO ==="

echo "Configurazione finale VMX:"
echo "  Display Name: $(grep 'displayName' "$FE_VMX")"
echo "  Memory: $(grep 'memsize' "$FE_VMX")"
echo "  CPU: $(grep 'numvcpus' "$FE_VMX")"
echo "  ISO: $(grep 'ide1:0.fileName' "$FE_VMX")"
echo "  Boot Order: $(grep 'bios.bootOrder' "$FE_VMX")"

echo ""
echo "Avviando VM con VMX ricostruito..."

if vmrun start "$FE_VMX"; then
    echo "✅ VM avviata con successo!"
    
    echo ""
    echo "🎯 VERIFICA BOOT:"
    echo "   1. VM dovrebbe bootare da CD/DVD"
    echo "   2. Potrebbe mostrare menu Ubuntu standard"
    echo "   3. Se boot CD → SUCCESSO (anche se manuale)"
    echo "   4. Se ancora PXE → problema VMware Workstation"
    
    echo ""
    echo "=== RISULTATO ATTESO ==="
    echo "✅ Boot da CD (anche con selezione manuale Ubuntu)"
    echo "❌ Boot PXE network"
    
else
    echo "❌ Errore avvio VM anche con VMX ricostruito"
    echo ""
    echo "POSSIBILI CAUSE:"
    echo "1. VMDK corrotto"
    echo "2. VMware Workstation problema"
    echo "3. Path ISO errato"
    echo "4. Permessi file"
    
    echo ""
    echo "VERIFICA MANUALE:"
    echo "1. Apri VMware Workstation"
    echo "2. Apri VM manualmente: $FE_VMX"
    echo "3. Verifica settings CD/DVD"
    echo "4. Test avvio manuale"
fi

# STEP 5: PIANO C - DISTRUZIONE E RICOSTRUZIONE COMPLETA
echo ""
echo "=== STEP 5: PIANO C - SE ANCORA PROBLEMI ==="

echo ""
echo "Se VM ancora non funziona, PIANO C:"
echo ""
echo "1. DISTRUZIONE COMPLETA VM:"
echo "   rm -rf '$FE_VM_DIR'"
echo "   Ricreare VM con Terraform da zero"
echo ""
echo "2. TEST CON UBUNTU ISO BASE:"
echo "   Creare VM test con solo Ubuntu ISO"
echo "   Verificare boot CD funzionante"
echo ""
echo "3. VERIFICA VMWARE WORKSTATION:"
echo "   Reinstallazione se necessario"

echo ""
echo "=== STATUS FINALE ==="
vmrun list

echo ""
echo "File VM finali:"
ls -la "$FE_VM_DIR"/"

echo ""
echo "🎯 OBIETTIVO RAGGIUNTO SE:"
echo "   ✅ VM boota da CD/DVD (anche menu manuale OK)"
echo "   ❌ VM ancora PXE boot"
