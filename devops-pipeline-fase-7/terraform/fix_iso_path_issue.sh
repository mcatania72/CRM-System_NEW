#!/bin/bash

# =============================================================================
# FIX ISO PATH ISSUE - CORREZIONE DEFINITIVA
# =============================================================================
# Corregge il problema del path relativo negli VMX files
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX PATH ISO NEI VMX FILES ===${NC}"
echo ""

# Directory corrente (dove sono gli ISO)
TERRAFORM_DIR="$(pwd)"
echo "Directory Terraform: $TERRAFORM_DIR"
echo ""

# Fix ogni VM
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
    ISO_NAME="$VM-autoinstall.iso"
    ISO_FULL_PATH="$TERRAFORM_DIR/$ISO_NAME"
    
    echo -e "${YELLOW}Fixing $VM...${NC}"
    
    if [ -f "$VMX_PATH" ]; then
        # Backup VMX
        cp "$VMX_PATH" "$VMX_PATH.backup-$(date +%Y%m%d-%H%M%S)"
        
        # Fix path ISO
        echo "  Current path: $(grep 'ide1:0.fileName' "$VMX_PATH" || echo "NOT FOUND")"
        sed -i "s|ide1:0.fileName = \".*\"|ide1:0.fileName = \"$ISO_FULL_PATH\"|" "$VMX_PATH"
        echo "  New path: $(grep 'ide1:0.fileName' "$VMX_PATH")"
        
        # Assicura che sia connected
        if ! grep -q "ide1:0.startConnected" "$VMX_PATH"; then
            echo 'ide1:0.startConnected = "TRUE"' >> "$VMX_PATH"
        fi
        
        echo -e "  ${GREEN}✓ Fixed${NC}"
    else
        echo -e "  ${RED}✗ VMX not found${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=== FIX COMPLETATO ===${NC}"
echo ""
echo "Ora riavvia le VM con:"
echo "  vmrun start \"\$HOME/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx\""
echo "  vmrun start \"\$HOME/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx\""
echo "  vmrun start \"\$HOME/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx\""
