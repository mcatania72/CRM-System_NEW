#!/bin/bash

# =============================================================================
# PULIZIA COMPLETA PER RESTART PULITO
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PULIZIA COMPLETA AMBIENTE ===${NC}"
echo ""

# 1. Stop tutte le VM
echo -e "${YELLOW}1. Fermando tutte le VM...${NC}"
vmrun list | grep -v "Total" | while read vm; do
    echo "   Stopping: $vm"
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 5

# Verifica
echo "   VM attive: $(vmrun list | grep -c VMware || echo '0')"

# 2. Pulizia Terraform
echo ""
echo -e "${YELLOW}2. Pulizia Terraform state...${NC}"
terraform destroy -auto-approve 2>/dev/null || echo "   (nessuno stato da pulire)"
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* tfplan

# 3. Rimuovi directory VM
echo ""
echo -e "${YELLOW}3. Rimuovendo directory VM...${NC}"
sudo rm -rf ~/VMware_VMs/SPESE_*
ls ~/VMware_VMs/ | grep SPESE || echo "   ✓ Nessuna directory SPESE"

# 4. Rimuovi ISO e file generati
echo ""
echo -e "${YELLOW}4. Rimuovendo ISO e file generati...${NC}"
rm -f *.iso
rm -f cloud-init-*.yml network-config-*.yml
rm -f create-vm-*.sh setup-k8s-*.sh
rm -f create_autoinstall_iso_fixed.sh
rm -rf autoinstall-*/ /tmp/iso-*

# 5. Verifica spazio disco
echo ""
echo -e "${YELLOW}5. Spazio disco recuperato:${NC}"
df -h / | grep -v Filesystem

# 6. Verifica finale
echo ""
echo -e "${GREEN}=== PULIZIA COMPLETATA ===${NC}"
echo "VM attive: $(vmrun list | head -1)"
echo "Directory SPESE: $(ls ~/VMware_VMs/ 2>/dev/null | grep -c SPESE || echo '0')"
echo "ISO files: $(ls *.iso 2>/dev/null | wc -l)"
echo "Spazio libero: $(df -h / | awk 'NR==2 {print $4}')"

echo ""
echo -e "${GREEN}✓ Ambiente pulito e pronto per nuovo deployment!${NC}"
