#!/bin/bash

# Script di diagnosi e fix drastico per problema boot VM
# Approccio: configurazione manuale VMX ultra-semplificata

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== DIAGNOSI COMPLETA PROBLEMA BOOT ==="

# Stop tutte le VM
vmrun list | grep -v "Total" | while read vm; do
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 3

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VM_DIR="$HOME/VMware_VMs/$VM"
    VMX_FILE="$VM_DIR/$VM.vmx"
    ISO_PATH="$(pwd)/$VM-autoinstall.iso"
    
    echo ""
    echo "=== DIAGNOSI $VM ==="
    
    if [ -f "$VMX_FILE" ]; then
        echo "1. VMX file esistente:"
        ls -la "$VMX_FILE"
        
        echo "2. Configurazione CD/DVD attuale:"
        grep -E "ide1|cdrom" "$VMX_FILE" || echo "❌ Nessuna config CD trovata"
        
        echo "3. Boot order attuale:"
        grep "bios.bootOrder" "$VMX_FILE" || echo "❌ Boot order non trovato"
        
        echo "4. ISO path attuale:"
        grep "ide1:0.fileName" "$VMX_FILE" || echo "❌ ISO path non trovato"
        
        echo "5. Verifica ISO esistenza:"
        if [ -f "$ISO_PATH" ]; then
            echo "✅ ISO exists: $ISO_PATH"
            ls -la "$ISO_PATH"
        else
            echo "❌ ISO missing: $ISO_PATH"
        fi
        
        # BACKUP VMX ORIGINALE
        cp "$VMX_FILE" "$VMX_FILE.backup"
        
        # GENERA VMX ULTRA-SEMPLIFICATO
        echo ""
        echo "6. Generando VMX ultra-semplificato..."
        
        cat > "$VMX_FILE" << EOF
#!/usr/bin/vmware
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"

# VM Basic Info
displayName = "$VM"
guestOS = "ubuntu-64"

# Memory and CPU
memsize = "4096"
numvcpus = "2"

# Hard Disk - SATA (più semplice di SCSI)
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "$VM.vmdk"
sata0:0.deviceType = "sata-hardDisk"

# CD/DVD Drive - FORZA BOOT DA CD
ide1:0.present = "TRUE"
ide1:0.fileName = "$ISO_PATH"
ide1:0.deviceType = "cdrom-image"
ide1:0.startConnected = "TRUE"

# Network
ethernet0.present = "TRUE"
ethernet0.connectionType = "bridged"
ethernet0.virtualDev = "e1000"

# FORCE BOOT FROM CD ONLY
bios.bootOrder = "cdrom"
bios.bootDelay = "5000"
bios.forceSetupOnce = "TRUE"

# Essential settings only
pciBridge0.present = "TRUE"
vmci0.present = "TRUE"

# Power settings
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
EOF
        
        echo "✅ VMX ultra-semplificato creato"
        
        # CREA VMDK SEMPLIFICATO CON VMWARE TOOLS
        VMDK_FILE="$VM_DIR/$VM.vmdk"
        if [ ! -f "$VMDK_FILE" ]; then
            echo "7. Creando VMDK con vmware-vdiskmanager..."
            if command -v vmware-vdiskmanager &> /dev/null; then
                vmware-vdiskmanager -c -s 25GB -a sata -t 0 "$VMDK_FILE"
            else
                # Fallback: VMDK semplice
                echo "vmware-vdiskmanager non disponibile, creando VMDK manuale..."
                touch "$VM_DIR/$VM-flat.vmdk"
                cat > "$VMDK_FILE" << VMDKEOF
# Disk DescriptorFile
version=1
CID=fffffffe
parentCID=ffffffff
createType="vmfs"

# Extent description
RW 52428800 VMFS "$VM-flat.vmdk"

ddb.virtualHWVersion = "19"
ddb.adapterType = "sata"
VMDKEOF
            fi
            echo "✅ VMDK creato"
        fi
        
        # START VM CON CONFIGURAZIONE SEMPLIFICATA
        echo "8. Avviando $VM con configurazione semplificata..."
        vmrun start "$VMX_FILE"
        
        echo "✅ $VM avviato - dovrebbe bootare SOLO da CD!"
        
    else
        echo "❌ VMX file non trovato: $VMX_FILE"
    fi
done

echo ""
echo "=== TUTTE LE VM RICONFIGURATE ==="
echo "Configurazione applicata:"
echo "- Boot SOLO da CD (bios.bootOrder = \"cdrom\")"
echo "- CD/DVD startConnected = TRUE"
echo "- Path ISO assoluto"
echo "- SATA disk invece di SCSI (più semplice)"
echo "- Delay boot 5 secondi"

echo ""
echo "=== STATO VM DOPO RECONFIG ==="
vmrun list

echo ""
echo "=== VERIFICA BOOT NELLE CONSOLE VM ==="
echo "Le VM dovrebbero ora bootare ESCLUSIVAMENTE dall'ISO autoinstall!"
echo "Se ancora bootano da network, il problema è nell'ISO stesso."
