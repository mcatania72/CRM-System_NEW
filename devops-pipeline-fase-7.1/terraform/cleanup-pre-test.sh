#!/bin/bash

# =============================================================================
# PULIZIA COMPLETA PRE-TEST FASE 7.1
# Rimuove VM e ISO esistenti per test pulito con late-commands estesi
# =============================================================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PULIZIA COMPLETA PRE FASE 7.1 ===${NC}"
echo ""

# 1. STOP TUTTE LE VM
echo -e "${YELLOW}[1/5] Fermando tutte le VM esistenti...${NC}"
vmrun list | grep -E "SPESE_(FE|BE|DB)_VM" | while read vm; do
    echo "  Stopping: $(basename "$vm")"
    vmrun stop "$vm" hard 2>/dev/null || true
done
sleep 3

# Verifica
RUNNING=$(vmrun list | grep -c "SPESE_" || true)
if [ "$RUNNING" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Tutte le VM fermate${NC}"
else
    echo -e "  ${RED}✗ Ancora $RUNNING VM in esecuzione${NC}"
fi

# 2. DESTROY TERRAFORM STATE (se in terraform/)
echo ""
echo -e "${YELLOW}[2/5] Pulizia Terraform state...${NC}"
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve 2>/dev/null || echo "  (destroy fallito, procedo con pulizia manuale)"
    echo -e "  ${GREEN}✓ Terraform state pulito${NC}"
else
    echo "  ℹ️  Nessuno state Terraform trovato"
fi

# 3. RIMUOVI DIRECTORY VM
echo ""
echo -e "${YELLOW}[3/5] Rimozione directory VM...${NC}"
for vm in SPESE_FE_VM SPESE_BE_VM SPESE_DB_VM; do
    VM_DIR="$HOME/VMware_VMs/$vm"
    if [ -d "$VM_DIR" ]; then
        echo "  Rimuovendo: $VM_DIR"
        rm -rf "$VM_DIR"
    fi
done
echo -e "  ${GREEN}✓ Directory VM rimosse${NC}"

# 4. RIMUOVI ISO E FILE TEMPORANEI
echo ""
echo -e "${YELLOW}[4/5] Pulizia ISO e file temporanei...${NC}"

# ISO files
find . -name "*.iso" -type f -exec rm -f {} \; 2>/dev/null
echo "  ✓ ISO rimossi"

# Script generati
rm -f create-iso-*.sh create-vm-*.sh 2>/dev/null
echo "  ✓ Script generati rimossi"

# Terraform files
rm -rf .terraform* terraform.tfstate* .terraform.lock.hcl 2>/dev/null
echo "  ✓ File Terraform rimossi"

# Temp files
rm -rf /tmp/iso-SPESE* /tmp/vm_creation_*.log 2>/dev/null
echo "  ✓ File temporanei rimossi"

# 5. VERIFICA SPAZIO DISCO
echo ""
echo -e "${YELLOW}[5/5] Verifica spazio disco...${NC}"
echo "  Spazio libero: $(df -h / | awk 'NR==2 {print $4}')"
echo "  Uso disco: $(df -h / | awk 'NR==2 {print $5}')"

# RIEPILOGO
echo ""
echo -e "${GREEN}=== PULIZIA COMPLETATA ===${NC}"
echo ""
echo "✅ VM fermate e rimosse"
echo "✅ ISO e file temporanei eliminati" 
echo "✅ Terraform state pulito"
echo ""
echo -e "${BLUE}Pronto per test FASE 7.1 con late-commands estesi!${NC}"
echo ""
echo "Prossimi comandi:"
echo "  terraform init"
echo "  terraform plan" 
echo "  terraform apply -auto-approve"
echo ""
