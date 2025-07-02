#!/bin/bash

# =============================================================================
# CLEANUP COMPLETO E SICURO PER TERRAFORM + VMWARE
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== CLEANUP COMPLETO TERRAFORM + VMWARE ===${NC}"
echo ""

# Step 1: Fix Terraform lock file
echo -e "${YELLOW}Step 1: Fixing Terraform lock file...${NC}"
rm -f .terraform.lock.hcl
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Step 2: Stop all VMs
echo -e "${YELLOW}Step 2: Stopping all VMs...${NC}"
vmrun list | grep -v "Total" | while read vm; do
    echo "  Stopping: $vm"
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 5
echo -e "${GREEN}✓ All VMs stopped${NC}"
echo ""

# Step 3: Destroy Terraform state
echo -e "${YELLOW}Step 3: Destroying Terraform state...${NC}"
terraform destroy -auto-approve || echo "  (Terraform destroy completed with warnings)"
echo -e "${GREEN}✓ Terraform state destroyed${NC}"
echo ""

# Step 4: Remove VM directories
echo -e "${YELLOW}Step 4: Removing VM directories...${NC}"
for vm_dir in ~/VMware_VMs/SPESE_*; do
    if [ -d "$vm_dir" ]; then
        echo "  Removing: $vm_dir"
        sudo rm -rf "$vm_dir"
    fi
done
echo -e "${GREEN}✓ VM directories removed${NC}"
echo ""

# Step 5: Clean generated files
echo -e "${YELLOW}Step 5: Cleaning generated files...${NC}"
rm -f *.iso *.yml *.sh tfplan terraform.tfstate* 
rm -rf .terraform/ autoinstall-*/
echo -e "${GREEN}✓ Generated files cleaned${NC}"
echo ""

# Step 6: Verification
echo -e "${BLUE}=== CLEANUP VERIFICATION ===${NC}"
echo "Running VMs: $(vmrun list | head -1)"
echo "SPESE directories: $(ls ~/VMware_VMs/ | grep -c SPESE || echo "0") found"
echo "ISO files: $(ls *.iso 2>/dev/null | wc -l) found"
echo "Terraform state: $(ls terraform.tfstate* 2>/dev/null | wc -l) files found"
echo ""

echo -e "${GREEN}=== CLEANUP COMPLETATO ===${NC}"
echo ""
echo "Prossimi step:"
echo "1. git pull origin main (per aggiornamenti)"
echo "2. terraform init"
echo "3. terraform plan -out=tfplan"
echo "4. terraform apply tfplan"
