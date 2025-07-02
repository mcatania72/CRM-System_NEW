#!/bin/bash

# Script per creare manualmente gli ISO autoinstall
# Replica esatto del comando nel null_resource

set -e

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

# Verifica prerequisiti
which genisoimage || (echo "Installing genisoimage..." && sudo apt-get update && sudo apt-get install -y genisoimage)
which 7z || (echo "Installing p7zip-full..." && sudo apt-get update && sudo apt-get install -y p7zip-full)

# Array delle VMs
declare -A VMS
VMS[FE]="SPESE_FE_VM"
VMS[BE]="SPESE_BE_VM" 
VMS[DB]="SPESE_DB_VM"

UBUNTU_ISO="/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso"

for KEY in "${!VMS[@]}"; do
    VM_NAME="${VMS[$KEY]}"
    
    echo "=== Creating autoinstall ISO for $VM_NAME ==="
    
    # Create temp directory for ISO creation
    TEMP_DIR="/tmp/autoinstall-${KEY}-$$"
    mkdir -p "$TEMP_DIR/source-files"
    
    # Extract original ISO
    echo "Extracting Ubuntu ISO..."
    if ! 7z -y x "$UBUNTU_ISO" -o"$TEMP_DIR/source-files" >/dev/null 2>&1; then
        echo "❌ Errore estrazione ISO"
        exit 1
    fi
    
    # Create autoinstall directory
    mkdir -p "$TEMP_DIR/source-files/server"
    
    # Copy autoinstall files
    if [ ! -f "autoinstall-${KEY}/user-data" ]; then
        echo "❌ user-data non trovato: autoinstall-${KEY}/user-data"
        exit 1
    fi
    
    cp "autoinstall-${KEY}/user-data" "$TEMP_DIR/source-files/server/"
    cp "autoinstall-${KEY}/meta-data" "$TEMP_DIR/source-files/server/"
    
    # Verify files copied
    echo "Files copied to server directory:"
    ls -la "$TEMP_DIR/source-files/server/"
    
    # Modify grub for autoinstall
    GRUB_FILE="$TEMP_DIR/source-files/boot/grub/grub.cfg"
    if [ -f "$GRUB_FILE" ]; then
        sed -i 's/timeout=30/timeout=5/' "$GRUB_FILE"
        sed -i "0,/menuentry \"Try or Install Ubuntu Server\"/s//menuentry \"Autoinstall ${VM_NAME}\" {\n\tset gfxpayload=keep\n\tlinux\t\/casper\/vmlinuz autoinstall ds=nocloud;s=\/cdrom\/server\/ ---\n\tinitrd\t\/casper\/initrd\n}\n\nmenuentry \"Try or Install Ubuntu Server\"/" "$GRUB_FILE"
    else
        echo "❌ Grub config non trovato: $GRUB_FILE"
        exit 1
    fi
    
    # Create autoinstall ISO
    OUTPUT_ISO="${VM_NAME}-autoinstall.iso"
    echo "Creating ISO: $OUTPUT_ISO"
    
    if genisoimage -r -V "${VM_NAME} Autoinstall" \
        -cache-inodes -J -joliet-long -l \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$OUTPUT_ISO" \
        "$TEMP_DIR/source-files" >/dev/null 2>&1; then
        
        echo "✅ Autoinstall ISO created: $OUTPUT_ISO"
        ls -la "$OUTPUT_ISO"
    else
        echo "❌ Errore creazione ISO"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    echo ""
done

echo "=== TUTTI GLI ISO CREATI ==="
ls -la *-autoinstall.iso
