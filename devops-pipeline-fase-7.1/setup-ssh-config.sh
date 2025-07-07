#!/bin/bash

# =============================================================================
# SETUP SSH CONFIG PER ZERO TOUCH
# Configura SSH su DEV_VM per accettare automaticamente le VM
# =============================================================================

set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SETUP SSH CONFIG PER ZERO TOUCH ===${NC}"
echo ""

# 1. Backup SSH config esistente
if [ -f ~/.ssh/config ]; then
    cp ~/.ssh/config ~/.ssh/config.backup.$(date +%Y%m%d-%H%M%S)
    echo "✓ Backup SSH config esistente"
fi

# 2. Aggiungi configurazione per VM CRM
echo -e "${YELLOW}Configurazione SSH per VM CRM...${NC}"

# Verifica se la configurazione esiste già
if ! grep -q "# CRM VMs Zero Touch" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << 'EOF'

# CRM VMs Zero Touch
Host 192.168.1.101 192.168.1.102 192.168.1.103
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    User devops
    
# Alias per VM
Host fe-vm
    HostName 192.168.1.101
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User devops

Host be-vm
    HostName 192.168.1.102
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User devops

Host db-vm
    HostName 192.168.1.103
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User devops
EOF
    echo "✓ Configurazione aggiunta"
else
    echo "✓ Configurazione già presente"
fi

# 3. Set permessi corretti
chmod 600 ~/.ssh/config

# 4. Pulisci known_hosts esistenti per le VM
echo -e "${YELLOW}Pulizia known_hosts...${NC}"
for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do
    ssh-keygen -f ~/.ssh/known_hosts -R $ip 2>/dev/null || true
done
echo "✓ Known hosts puliti"

echo ""
echo -e "${GREEN}=== SSH CONFIG COMPLETATO ===${NC}"
echo ""
echo "Ora puoi usare:"
echo "  ssh 192.168.1.101  # Senza warning"
echo "  ssh fe-vm          # Alias comodo"
echo "  ssh be-vm"
echo "  ssh db-vm"
echo ""
echo "ZERO interazioni richieste! 🚀"
