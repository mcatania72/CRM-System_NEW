#!/bin/bash

# ANALISI COMPLETA PROBLEMA BOOT VMWARE
# Root cause analysis sistematico

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "ANALISI COMPLETA PROBLEMA BOOT VMWARE"
echo "=========================================="

# STEP 1: ANALISI CONFIGURAZIONE VMX
echo ""
echo "=== STEP 1: ANALISI CONFIGURAZIONE VMX ==="

for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_FILE="$HOME/VMware_VMs/$VM/$VM.vmx"
    echo ""
    echo "--- VM: $VM ---"
    
    if [ -f "$VMX_FILE" ]; then
        echo "✅ VMX file trovato: $VMX_FILE"
        
        echo "CD/DVD Configuration:"
        grep -E "ide1:0\." "$VMX_FILE" | while read line; do
            echo "  $line"
        done
        
        echo "Boot Configuration:"
        grep -E "bios\." "$VMX_FILE" | while read line; do
            echo "  $line"
        done
        
        # Verifica path ISO nel VMX
        ISO_PATH=$(grep "ide1:0.fileName" "$VMX_FILE" | cut -d'"' -f2)
        echo "ISO Path nel VMX: $ISO_PATH"
        
        if [ -f "$ISO_PATH" ]; then
            echo "✅ ISO file exists at VMX path"
        else
            echo "❌ ISO file NOT FOUND at VMX path: $ISO_PATH"
        fi
        
    else
        echo "❌ VMX file NOT FOUND: $VMX_FILE"
    fi
done

# STEP 2: ANALISI ISO AUTOINSTALL
echo ""
echo "=== STEP 2: ANALISI ISO AUTOINSTALL ==="

for ISO in SPESE_*-autoinstall.iso; do
    if [ -f "$ISO" ]; then
        echo ""
        echo "--- ISO: $ISO ---"
        
        # Verifica dimensione
        SIZE=$(ls -lh "$ISO" | awk '{print $5}')
        echo "Dimensione: $SIZE"
        
        # Verifica se ISO è bootable con file command
        echo "File type:"
        file "$ISO"
        
        # Verifica boot catalog ISO con isoinfo
        if command -v isoinfo >/dev/null 2>&1; then
            echo "Boot Catalog Info:"
            isoinfo -d -i "$ISO" | grep -E "El Torito|Boot"
        else
            echo "⚠️ isoinfo non disponibile per verifica boot catalog"
        fi
        
        # Test mount ISO e verifica contenuto
        MOUNT_DIR="/tmp/iso_test_$$"
        mkdir -p "$MOUNT_DIR"
        
        if sudo mount -o loop "$ISO" "$MOUNT_DIR" 2>/dev/null; then
            echo "✅ ISO mount successful"
            
            echo "Contenuto root ISO:"
            ls -la "$MOUNT_DIR" | head -10
            
            echo "Boot files:"
            find "$MOUNT_DIR" -name "*boot*" -o -name "*grub*" -o -name "*isolinux*" | head -5
            
            echo "Autoinstall files:"
            find "$MOUNT_DIR" -name "user-data" -o -name "meta-data" -o -name "*autoinstall*"
            
            # Verifica GRUB config
            if [ -f "$MOUNT_DIR/boot/grub/grub.cfg" ]; then
                echo "GRUB menu entries:"
                grep -A 2 "menuentry" "$MOUNT_DIR/boot/grub/grub.cfg" | head -10
            else
                echo "❌ GRUB config not found"
            fi
            
            sudo umount "$MOUNT_DIR"
            rmdir "$MOUNT_DIR"
        else
            echo "❌ ISO mount FAILED - ISO might be corrupted"
        fi
        
    else
        echo "❌ ISO not found: $ISO"
    fi
done

# STEP 3: VERIFICA VMWARE ENVIRONMENT
echo ""
echo "=== STEP 3: VERIFICA VMWARE ENVIRONMENT ==="

echo "VMware version:"
vmware --version 2>/dev/null || vmrun 2>&1 | head -1

echo "VM attualmente in esecuzione:"
vmrun list

echo "Processo VMware:"
ps aux | grep vmware | grep -v grep

# STEP 4: TEST BOOT ALTERNATIVO
echo ""
echo "=== STEP 4: TEST CONFIGURAZIONE BOOT ALTERNATIVA ==="

# Prova configurazione boot alternativa per FE_VM
VM="SPESE_FE_VM"
VMX_FILE="$HOME/VMware_VMs/$VM/$VM.vmx"
ISO_PATH="$(pwd)/$VM-autoinstall.iso"

if [ -f "$VMX_FILE" ] && [ -f "$ISO_PATH" ]; then
    echo "Test configurazione boot alternativa per $VM..."
    
    # Stop VM
    vmrun stop "$VMX_FILE" hard 2>/dev/null || true
    sleep 3
    
    # Backup VMX
    cp "$VMX_FILE" "$VMX_FILE.original"
    
    # Configurazione boot semplificata
    cat >> "$VMX_FILE" << EOF

# BOOT TEST - FORCED CD BOOT
ide1:0.startConnected = "TRUE"
ide1:0.autodetect = "TRUE"
bios.bootOrder = "cdrom"
bios.bootDelay = "10000"
bios.forceSetupOnce = "FALSE"

# Debug settings
isolation.bios.bootOrder = "cdrom"
EOF
    
    echo "✅ Configurazione test applicata"
    echo "Configurazione CD/DVD finale:"
    grep -E "ide1:0\.|bios\." "$VMX_FILE"
    
    # Test start VM
    echo "Avviando VM per test boot..."
    vmrun start "$VMX_FILE"
    
    echo "✅ VM avviata - controlla console per boot behavior"
    
else
    echo "❌ File mancanti per test boot alternativo"
fi

# STEP 5: SUMMARY E RACCOMANDAZIONI
echo ""
echo "=== STEP 5: SUMMARY PROBLEMI IDENTIFICATI ==="

echo ""
echo "POSSIBILI CAUSE PROBLEMA BOOT:"
echo "1. ISO non bootable (El Torito boot catalog mancante/corrotto)"
echo "2. GRUB config nell'ISO non corretto"
echo "3. VMware non riconosce CD/DVD drive"
echo "4. Boot order non rispettato"
echo "5. Path ISO nel VMX errato"
echo "6. ISO mount fallisce"

echo ""
echo "PROSSIMI STEP RACCOMANDATI:"
echo "A. Se ISO mount fallisce → Ricreare ISO con metodo diverso"
echo "B. Se GRUB entries mancanti → Fix grub.cfg nell'ISO"  
echo "C. Se VM boot da network comunque → Problema VMware virtualizzazione"
echo "D. Se tutto sembra OK → Provare ISO Ubuntu standard per test"

echo ""
echo "=== ANALISI COMPLETATA ==="
echo "Controlla output sopra per identificare root cause"
