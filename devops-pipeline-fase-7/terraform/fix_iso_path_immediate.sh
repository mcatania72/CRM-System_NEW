#!/bin/bash

# Script per correggere path ISO nelle VM esistenti
# Fix per problema boot da network invece che da CD/DVD

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== FIX PATH ISO ASSOLUTO ==="

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VM_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
    ISO_PATH="$(pwd)/$VM-autoinstall.iso"
    
    echo "Fixing $VM..."
    echo "  Path attuale: $(grep 'ide1:0.fileName' "$VM_PATH" 2>/dev/null || echo 'Non trovato')"
    echo "  Path corretto: $ISO_PATH"
    
    if [ -f "$VM_PATH" ]; then
        # Stop VM
        vmrun stop "$VM_PATH" hard 2>/dev/null || true
        sleep 2
        
        # Fix path ISO assoluto
        sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ISO_PATH\"|" "$VM_PATH"
        
        # Assicurati che il CD sia startConnected
        if ! grep -q "ide1:0.startConnected" "$VM_PATH"; then
            echo 'ide1:0.startConnected = "TRUE"' >> "$VM_PATH"
        else
            sed -i 's|ide1:0.startConnected = "FALSE"|ide1:0.startConnected = "TRUE"|' "$VM_PATH"
        fi
        
        # Verifica correzione
        echo "  Nuovo path: $(grep 'ide1:0.fileName' "$VM_PATH")"
        
        # Test che ISO esista al path assoluto
        if [ -f "$ISO_PATH" ]; then
            echo "  ✅ ISO verificato al path assoluto"
        else
            echo "  ❌ ISO NON TROVATO al path assoluto!"
        fi
        
        # Restart VM
        echo "  Riavviando $VM..."
        vmrun start "$VM_PATH"
        echo "  ✅ $VM riavviata"
    else
        echo "  ❌ VMX file non trovato: $VM_PATH"
    fi
    echo ""
done

echo "=== VERIFICA POST-FIX ==="
vmrun list

echo ""
echo "=== ATTENDI 2 MINUTI E CONTROLLA CONSOLE VM ==="
echo "Le VM dovrebbero ora bootare dall'ISO autoinstall invece di PXE network boot"

# Monitoring opzionale
echo ""
echo "=== MONITORING BOOT (opzionale) ==="
for i in {1..8}; do
    echo "Check #$i - $(date)"
    
    for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
        case $VM in
            "SPESE_FE_VM") IP="192.168.1.101";;
            "SPESE_BE_VM") IP="192.168.1.102";;  
            "SPESE_DB_VM") IP="192.168.1.103";;
        esac
        
        echo -n "  $VM ($IP): "
        if ping -c 1 $IP >/dev/null 2>&1; then
            echo "🌐 Ubuntu installato e attivo!"
        else
            echo "⏳ Installazione in corso..."
        fi
    done
    
    if [ $i -lt 8 ]; then
        echo "  Prossimo check tra 2 minuti..."
        sleep 120
    fi
done

echo ""
echo "=== FIX COMPLETATO ==="
echo "Se le VM non rispondono ancora, l'installazione Ubuntu autoinstall è in corso (15-20 min)"
