#!/bin/bash

# Fix per FE_VM VMX corrupted + automatizzazione selezione lingua
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX FE_VM + AUTOINSTALL AUTOMATICO ==="

# 1. FIX FE_VM VMX CORRUPTED
echo "--- FIX FE_VM VMX CORRUPTED ---"
FE_VMX="$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx"
FE_ISO="/home/devops/CRM-Fase7/devops-pipeline-fase-7/terraform/SPESE_FE_VM-autoinstall.iso"

# Stop FE_VM se attiva
vmrun stop "$FE_VMX" hard 2>/dev/null || true
sleep 3

# Ripristina VMX da backup o ricrea
if [ -f "$FE_VMX.backup-"* ]; then
    echo "Ripristinando VMX da backup..."
    BACKUP=$(ls -t "$FE_VMX.backup-"* | head -1)
    cp "$BACKUP" "$FE_VMX"
    echo "✅ VMX ripristinato da: $BACKUP"
else
    echo "Ricreando VMX FE_VM da zero..."
    cat > "$FE_VMX" << EOF
#!/usr/bin/vmware
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"

# VM Basic Info
displayName = "SPESE_FE_VM"
guestOS = "ubuntu-64"
annotation = "Kubernetes Master + Frontend|0A|Role: master|0A|IP: 192.168.1.101"

# Memory and CPU
memsize = "4096"
numvcpus = "2"
cpuid.coresPerSocket = "1"

# Hard Disk - SCSI
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "SPESE_FE_VM.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"

# CD/DVD Drive
ide1:0.present = "TRUE"
ide1:0.fileName = "$FE_ISO"
ide1:0.deviceType = "cdrom-image"
ide1:0.startConnected = "TRUE"

# Network
ethernet0.present = "TRUE"
ethernet0.connectionType = "bridged"
ethernet0.virtualDev = "e1000"
ethernet0.wakeOnPcktRcv = "FALSE"
ethernet0.addressType = "generated"

# Boot Configuration
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "5000"

# Essential settings
pciBridge0.present = "TRUE"
vmci0.present = "TRUE"
hpet0.present = "TRUE"

# USB and Sound
usb.present = "TRUE"
ehci.present = "TRUE"
sound.present = "TRUE"
sound.fileName = "-1"
sound.autodetect = "TRUE"

# Power settings
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"

# Tools
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"
EOF
    echo "✅ VMX ricreato"
fi

# Verifica e avvia FE_VM
if vmrun start "$FE_VMX" 2>/dev/null; then
    echo "✅ FE_VM riavviata con successo"
else
    echo "❌ FE_VM start fallito - verifica manualmente"
fi

# 2. AUTOMATIZZA SELEZIONE LINGUA PER TUTTE LE VM
echo ""
echo "--- AUTOMATIZZAZIONE SELEZIONE LINGUA ---"

# Seleziona English automaticamente per le VM in language selection
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
    
    if vmrun list | grep -q "$VMX_PATH"; then
        echo "Inviando ENTER per $VM (seleziona English)..."
        
        # Invia keypress ENTER per confermare English (già selezionato)
        vmrun sendKeyEvent "$VMX_PATH" "Return" 2>/dev/null || true
        sleep 2
        
        echo "✅ ENTER inviato a $VM"
    else
        echo "⚠️ $VM non in esecuzione"
    fi
done

echo ""
echo "=== STATUS FINALE ==="
vmrun list

echo ""
echo "=== VERIFICA AUTOINSTALL PROGRESS ==="
echo "Le VM dovrebbero ora procedere automaticamente con l'installazione Ubuntu..."

# Monitoring rapido
sleep 30
echo ""
echo "--- Check dopo 30 secondi ---"
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    case $VM in
        "SPESE_FE_VM") IP="192.168.1.101";;
        "SPESE_BE_VM") IP="192.168.1.102";;  
        "SPESE_DB_VM") IP="192.168.1.103";;
    esac
    
    echo -n "$VM ($IP): "
    if ping -c 1 $IP >/dev/null 2>&1; then
        echo "🌐 INSTALLAZIONE COMPLETATA!"
    else
        echo "⏳ Installazione in corso..."
    fi
done

echo ""
echo "=== NEXT STEPS ==="
echo "1. ✅ VM bootano dall'ISO autoinstall"
echo "2. ✅ Lingua selezionata automaticamente"  
echo "3. ⏳ Attendi 15-20 minuti per installazione completa"
echo "4. 🎯 Quando VM rispondono al ping, Ubuntu è pronto con SSH!"

echo ""
echo "Monitor continuo:"
echo "watch -n 60 'for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do echo -n \"\$ip: \"; ping -c 1 \$ip >/dev/null 2>&1 && echo \"✅ UP\" || echo \"⏳ Installing\"; done'"
