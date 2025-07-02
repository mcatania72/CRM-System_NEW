#!/bin/bash

# FIX DEFINITIVO - CORREGGI PATH ISO ASSOLUTO
# Root cause: VMX usa path relativo invece di assoluto

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX DEFINITIVO PATH ISO ASSOLUTO ==="

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_FILE="$HOME/VMware_VMs/$VM/$VM.vmx"
    ISO_PATH_ASSOLUTO="$(pwd)/$VM-autoinstall.iso"
    
    echo ""
    echo "--- FIXING $VM ---"
    echo "Path attuale nel VMX: $(grep 'ide1:0.fileName' "$VMX_FILE")"
    echo "Path corretto assoluto: $ISO_PATH_ASSOLUTO"
    
    # Verifica che ISO esista
    if [ -f "$ISO_PATH_ASSOLUTO" ]; then
        echo "✅ ISO verificato: $ISO_PATH_ASSOLUTO"
        
        # Stop VM
        vmrun stop "$VMX_FILE" hard 2>/dev/null || true
        sleep 3
        
        # Backup VMX
        cp "$VMX_FILE" "$VMX_FILE.backup-$(date +%H%M%S)"
        
        # CORREGGI PATH ISO NEL VMX
        sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ISO_PATH_ASSOLUTO\"|" "$VMX_FILE"
        
        # Verifica correzione
        echo "Nuovo path nel VMX: $(grep 'ide1:0.fileName' "$VMX_FILE")"
        
        # Restart VM
        echo "Riavviando $VM..."
        vmrun start "$VMX_FILE"
        
        echo "✅ $VM corretto e riavviato"
        
    else
        echo "❌ ISO non trovato: $ISO_PATH_ASSOLUTO"
    fi
done

echo ""
echo "=== VERIFICA FINALE ==="
vmrun list

echo ""
echo "=== PATH ISO NEI VMX DOPO FIX ==="
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_FILE="$HOME/VMware_VMs/$VM/$VM.vmx"
    echo "$VM: $(grep 'ide1:0.fileName' "$VMX_FILE")"
done

echo ""
echo "=== LE VM DOVREBBERO ORA BOOTARE DALL'ISO! ==="
echo "Controlla le console VM - dovrebbero mostrare GRUB invece di PXE boot"

# Monitoring automatico
echo ""
echo "=== MONITORING BOOT (60 secondi) ==="
sleep 60

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    case $VM in
        "SPESE_FE_VM") IP="192.168.1.101";;
        "SPESE_BE_VM") IP="192.168.1.102";;  
        "SPESE_DB_VM") IP="192.168.1.103";;
    esac
    
    echo -n "$VM ($IP): "
    if ping -c 1 $IP >/dev/null 2>&1; then
        echo "🌐 UBUNTU INSTALLATO! SSH disponibile"
    else
        echo "⏳ Installazione in corso... (15-20 min totali)"
    fi
done
