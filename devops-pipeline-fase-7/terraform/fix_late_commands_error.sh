#!/bin/bash

# =============================================================================
# FIX AUTOINSTALL USER-DATA - Corregge ordine comandi late-commands
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== FIX AUTOINSTALL LATE-COMMANDS ===${NC}"
echo ""

# Crea script per generare user-data corretto
cat > generate_fixed_userdata.sh << 'EOF'
#!/bin/bash

generate_userdata() {
    local VM_NAME="$1"
    local IP_ADDRESS="$2"
    local VM_ROLE="$3"
    
    cat << USERDATA
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    ethernets:
      ens33:
        dhcp4: false
        addresses:
          - ${IP_ADDRESS}/24
        gateway4: 192.168.1.1
        nameservers:
          addresses:
            - 8.8.8.8
            - 8.8.4.4
    version: 2
  apt:
    disable_components: []
    geoip: true
    preserve_sources_list: false
    primary:
      - arches: [amd64, i386]
        uri: http://archive.ubuntu.com/ubuntu
      - arches: [default]
        uri: http://ports.ubuntu.com/ubuntu-ports
  identity:
    hostname: ${VM_NAME,,}
    password: \$6\$xyz\$74AlwKA3Z5n2L6ujMzm/zQXHCluA4SRc2mBfO2/O5uUc2yM2n2tnbBMi/IVRLJuKwfjrLZjAT7arSy/
    username: devops
  ssh:
    allow-pw: true
    install-server: true
  storage:
    layout:
      name: direct
  packages:
    - docker.io
    - curl
    - wget
    - git
    - net-tools
  late-commands:
    # Sudoers setup
    - echo 'devops ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/devops
    - chmod 440 /target/etc/sudoers.d/devops
    # Network setup for static IP
    - |
      cat > /target/etc/netplan/00-installer-config.yaml << NETPLAN
      network:
        version: 2
        ethernets:
          ens33:
            dhcp4: false
            addresses:
              - ${IP_ADDRESS}/24
            gateway4: 192.168.1.1
            nameservers:
              addresses:
                - 8.8.8.8
                - 8.8.4.4
      NETPLAN
    - chmod 600 /target/etc/netplan/00-installer-config.yaml
    # Docker setup - con controlli di sicurezza
    - curtin in-target --target=/target -- systemctl enable docker || true
    - curtin in-target --target=/target -- groupadd -f docker || true
    - curtin in-target --target=/target -- usermod -aG docker devops || true
    # Marker file per completamento
    - touch /target/home/devops/autoinstall-complete
    # SSH key setup (opzionale)
    - mkdir -p /target/home/devops/.ssh
    - chmod 700 /target/home/devops/.ssh
    - chown -R 1000:1000 /target/home/devops
USERDATA
}

# Test generazione
echo "=== GENERAZIONE USER-DATA FISSO ==="
generate_userdata "SPESE_FE_VM" "192.168.1.101" "master" > test-user-data.yml
echo "User-data generato. Verificalo con:"
echo "cat test-user-data.yml"
EOF

chmod +x generate_fixed_userdata.sh

echo ""
echo -e "${YELLOW}OPZIONI DI FIX:${NC}"
echo ""
echo "1. QUICK FIX - Accedi alla VM e completa manualmente:"
echo "   - La VM è installata ma i late-commands sono falliti"
echo "   - Premi Enter nella console per avere una shell"
echo "   - Login con: devops / devops"
echo "   - Completa setup manualmente"
echo ""
echo "2. FULL FIX - Ricrea ISO con user-data corretto:"
echo "   - Esegui: ./generate_fixed_userdata.sh"
echo "   - Ricrea gli ISO con il nuovo user-data"
echo "   - Reinstalla le VM da zero"
echo ""
echo "3. RECOVERY - Continua con VM parzialmente configurata:"
echo "   - Accedi via console e sistema Docker manualmente"
echo "   - Poi procedi con setup Kubernetes"
echo ""
echo -e "${GREEN}RACCOMANDAZIONE:${NC} Usa Quick Fix (opzione 1) per FE_VM"
echo "Poi applica Full Fix per BE_VM e DB_VM"
