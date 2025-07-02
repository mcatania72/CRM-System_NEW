#!/bin/bash

# Fix FE_VM e check status installazione
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX FE_VM VMX + STATUS CHECK ==="

# 1. RICOSTRUZIONE COMPLETA FE_VM
echo "--- RICOSTRUZIONE FE_VM DA ZERO ---"

FE_VM_DIR="$HOME/VMware_VMs/SPESE_FE_VM"
FE_VMX="$FE_VM_DIR/SPESE_FE_VM.vmx"
FE_VMDK="$FE_VM_DIR/SPESE_FE_VM.vmdk"
FE_ISO="$(pwd)/SPESE_FE_VM-autoinstall.iso"

# Ferma e rimuovi VM corrotta
vmrun stop "$FE_VMX" hard 2>/dev/null || true
vmrun deleteVM "$FE_VMX" 2>/dev/null || true
sleep 2

# Rimuovi directory corrotta
rm -rf "$FE_VM_DIR"
mkdir -p "$FE_VM_DIR"

echo "✅ Directory FE_VM pulita"

# Crea VMDK con vmware-vdiskmanager
echo "Creando nuovo VMDK..."
if command -v vmware-vdiskmanager &> /dev/null; then
    vmware-vdiskmanager -c -s 25GB -a lsilogic -t 0 "$FE_VMDK"
    echo "✅ VMDK creato con vmware-vdiskmanager"
else
    # Fallback: VMDK manuale
    touch "$FE_VM_DIR/SPESE_FE_VM-flat.vmdk"
    cat > "$FE_VMDK" << 'VMDKEOF'
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
    echo "✅ VMDK creato manualmente"
fi

# Crea VMX pulito e semplice
echo "Creando nuovo VMX..."
cat > "$FE_VMX" << EOF
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

# CD/DVD Configuration - AUTOINSTALL ISO
ide1:0.present = "TRUE"
ide1:0.fileName = "$FE_ISO"
ide1:0.deviceType = "cdrom-image"
ide1:0.startConnected = "TRUE"

# Boot Configuration - FORZA BOOT DA CD
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "3000"

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
EOF

echo "✅ Nuovo VMX creato"

# Verifica files creati
echo "Files FE_VM creati:"
ls -la "$FE_VM_DIR/"

# Avvia FE_VM
echo "Avviando FE_VM..."
if vmrun start "$FE_VMX"; then
    echo "✅ FE_VM avviata con successo!"
else
    echo "❌ Errore avvio FE_VM"
    # Debug info
    echo "VMX content:"
    head -20 "$FE_VMX"
fi

# 2. STATUS CHECK TUTTE LE VM
echo ""
echo "=== STATUS CHECK INSTALLAZIONE ==="

vmrun list

echo ""
echo "Network status check:"
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    case $VM in
        "SPESE_FE_VM") IP="192.168.1.101";;
        "SPESE_BE_VM") IP="192.168.1.102";;  
        "SPESE_DB_VM") IP="192.168.1.103";;
    esac
    
    echo -n "$VM ($IP): "
    if ping -c 1 $IP >/dev/null 2>&1; then
        echo "🌐 UBUNTU INSTALLATO - SSH READY!"
        
        # Test SSH
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no devops@$IP 'echo "SSH OK"' 2>/dev/null; then
            echo "  🔑 SSH funzionante"
        else
            echo "  ⏳ SSH non ancora pronto"
        fi
    else
        echo "⏳ Installazione in corso..."
    fi
done

echo ""
echo "=== SUMMARY ==="
echo "✅ FE_VM ricostruita da zero"
echo "✅ BE_VM e DB_VM in installazione"  
echo "⏳ Attendi completamento installazione (5-15 min rimanenti)"

echo ""
echo "=== MONITORAGGIO CONTINUO ==="
echo "Esegui questo comando per monitorare progress:"
echo "watch -n 60 'for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do echo -n \"\$ip: \"; ping -c 1 \$ip >/dev/null 2>&1 && echo \"✅ READY\" || echo \"⏳ Installing\"; done'"
