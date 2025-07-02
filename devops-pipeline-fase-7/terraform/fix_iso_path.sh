#!/bin/bash

# Script per correggere path ISO nelle VM esistenti e riavviarle

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== CORREGGO PATH ISO IN TUTTE LE VM ==="

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VM_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
    ISO_PATH="$(pwd)/$VM-autoinstall.iso"
    
    echo "Correggendo $VM..."
    echo "  Path attuale ISO: $(grep 'ide1:0.fileName' "$VM_PATH" 2>/dev/null || echo 'Non trovato')"
    echo "  Path corretto: $ISO_PATH"
    
    if [ -f "$VM_PATH" ]; then
        # Stop VM
        vmrun stop "$VM_PATH" soft 2>/dev/null || true
        sleep 2
        
        # Correggi path ISO nel VMX
        sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ISO_PATH\"|" "$VM_PATH"
        
        # Verifica correzione
        echo "  Nuovo path: $(grep 'ide1:0.fileName' "$VM_PATH")"
        
        # Riavvia VM
        echo "  Riavviando $VM..."
        vmrun start "$VM_PATH"
        echo "  ✅ $VM riavviata"
    else
        echo "  ❌ VMX file non trovato: $VM_PATH"
    fi
    echo ""
done

echo "=== TUTTE LE VM CORRETTE E RIAVVIATE ==="
vmrun list

echo ""
echo "=== MONITORING BOOT VM ==="
echo "Attendi 2 minuti e poi verifica se le VM bootano dall'ISO..."

# Check ogni 30 secondi per 10 volte
for i in {1..10}; do
    echo ""
    echo "=== CHECK #$i - $(date) ==="
    
    for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
        case $VM in
            "SPESE_FE_VM") IP="192.168.1.101";;
            "SPESE_BE_VM") IP="192.168.1.102";;
            "SPESE_DB_VM") IP="192.168.1.103";;
        esac
        
        VM_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
        
        if vmrun list | grep -q "$VM_PATH"; then
            echo "  ✅ $VM running"
            if ping -c 1 $IP >/dev/null 2>&1; then
                echo "    🌐 $VM risponde al ping ($IP) - Ubuntu installato!"
            else
                echo "    ⏳ $VM non risponde ancora - installazione in corso"
            fi
        else
            echo "  ❌ $VM not running"
        fi
    done
    
    if [ $i -lt 10 ]; then
        echo "Prossimo check tra 30 secondi..."
        sleep 30
    fi
done

echo ""
echo "=== SCRIPT COMPLETATO ==="
echo "Se le VM non rispondono ancora al ping, l'installazione Ubuntu è in corso."
echo "L'installazione autoinstall richiede 15-20 minuti per VM."
