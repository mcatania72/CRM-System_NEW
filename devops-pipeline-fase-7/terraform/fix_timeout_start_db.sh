#!/bin/bash

# FIX TIMEOUT GRUB + START DB_VM

set -e

echo "=== FIX TIMEOUT E AVVIO DB_VM ==="

# 1. Fix timeout negli ISO (per futuri boot)
echo "Fixing GRUB timeout negli ISO..."
for ISO in SPESE_*-autoinstall.iso; do
    echo "Checking $ISO..."
    # Mount ISO
    sudo mkdir -p /mnt/iso-fix
    sudo mount -o loop "$ISO" /mnt/iso-fix
    
    # Check current timeout
    if grep -q "set timeout=5" /mnt/iso-fix/boot/grub/grub.cfg 2>/dev/null; then
        echo "  ✗ $ISO ha timeout=5 (dovrebbe essere 1)"
    fi
    
    sudo umount /mnt/iso-fix
done

# 2. Avvia DB_VM
echo ""
echo "Avvio DB_VM..."
if vmrun start "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx"; then
    echo "✓ DB_VM avviata con successo"
else
    echo "✗ Errore avvio DB_VM - verifico il problema..."
    
    # Check VMX syntax
    if grep -q "ide1:0.present = \"TRUE\"" "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx"; then
        echo "  VMX sembra OK"
    fi
    
    # Try reset and restart
    echo "  Provo reset..."
    vmrun reset "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx" hard 2>/dev/null || true
    sleep 2
    vmrun start "$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx" || {
        echo "  ✗ DB_VM non si avvia - potrebbe servire ricreazione"
        echo "  Usa: terraform destroy -target='null_resource.create_vms[\"DB\"]' -auto-approve"
        echo "       terraform apply -target='null_resource.create_vms[\"DB\"]' -auto-approve"
    }
fi

echo ""
echo "=== STATO FINALE ==="
vmrun list

echo ""
echo "=== ISTRUZIONI ==="
echo ""
echo "Per FE e BE (già in esecuzione):"
echo "  - Aspetta 5 secondi al menu GRUB (boot automatico)"
echo "  - O premi Enter per boot immediato"
echo ""
echo "Per DB (se avviata):"
echo "  - Stessa cosa: 5 secondi o Enter"
echo ""
echo "L'installazione procederà automatica dopo il boot!"
