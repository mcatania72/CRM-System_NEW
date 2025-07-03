#!/bin/bash

# =============================================================================
# PULIZIA COMPLETA E DEPLOYMENT ZERO TOUCH
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PULIZIA COMPLETA E PREPARAZIONE DEPLOYMENT ===${NC}"
echo ""

# 1. STOP TUTTE LE VM ATTIVE
echo -e "${YELLOW}1. Fermando tutte le VM attive...${NC}"
vmrun list | grep -v "Total" | while read vm; do
    echo "   Stopping: $vm"
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 5

# Verifica
echo "   VM attive dopo stop: $(vmrun list | grep -c VMware || echo '0')"

# 2. DESTROY TERRAFORM STATE
echo ""
echo -e "${YELLOW}2. Pulizia Terraform state...${NC}"
terraform destroy -auto-approve 2>/dev/null || echo "   (nessuno stato terraform da pulire)"

# 3. RIMUOVI DIRECTORY VM
echo ""
echo -e "${YELLOW}3. Rimuovendo directory VM...${NC}"
sudo rm -rf ~/VMware_VMs/SPESE_*_VM
echo "   ✓ Directory VM rimosse"

# 4. PULIZIA FILE GENERATI
echo ""
echo -e "${YELLOW}4. Rimuovendo file generati...${NC}"
rm -f *.iso
rm -f create-vm-*.sh
rm -f create-iso-*.sh
rm -f cloud-init-*.yml
rm -f autoinstall-*.yml
rm -f network-config-*.yml
rm -f setup-k8s-*.sh
rm -f k8s-join-command
rm -f tfplan terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/
rm -rf autoinstall-*/

# 5. VERIFICA SPAZIO DISCO
echo ""
echo -e "${YELLOW}5. Stato spazio disco:${NC}"
df -h / | awk 'NR<=2'

# 6. RIEPILOGO FINALE
echo ""
echo -e "${GREEN}=== PULIZIA COMPLETATA ===${NC}"
echo ""
echo "Stato sistema:"
echo "  VM attive: $(vmrun list | head -1)"
echo "  Directory SPESE: $(ls ~/VMware_VMs/ 2>/dev/null | grep -c SPESE || echo '0')"
echo "  ISO files: $(ls *.iso 2>/dev/null | wc -l)"
echo "  Terraform state: pulito"
echo ""
echo -e "${GREEN}Sistema pronto per nuovo deployment!${NC}"
echo ""
echo "Prossimi comandi:"
echo "  terraform init"
echo "  terraform plan -out=tfplan"
echo "  terraform apply tfplan"
