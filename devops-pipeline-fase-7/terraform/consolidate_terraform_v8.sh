#!/bin/bash

# =============================================================================
# TERRAFORM CONSOLIDATION - INTEGRA V8 IN TERRAFORM
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== CONSOLIDAMENTO TERRAFORM CON V8 ===${NC}"
echo ""

# Backup del main.tf attuale
echo -e "${YELLOW}1. Backup main.tf attuale...${NC}"
cp main.tf main.tf.backup-$(date +%Y%m%d-%H%M%S)
echo "✓ Backup creato"

# Crea nuovo template autoinstall corretto
echo ""
echo -e "${YELLOW}2. Creando template autoinstall V8...${NC}"

cat > templates/autoinstall-user-data.yml.tpl << 'EOF'
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
          - ${ip_address}/24
        gateway4: 192.168.1.1
        nameservers:
          addresses: [8.8.8.8, 8.8.4.4]
    version: 2
  identity:
    hostname: ${vm_name_lower}
    password: '${password_hash}'
    username: ${username}
  ssh:
    allow-pw: true
    install-server: true
  storage:
    layout:
      name: direct
  packages:
    - openssh-server
    - curl
    - git
  late-commands:
    - echo '${username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${username}
    - chmod 440 /target/etc/sudoers.d/${username}
EOF

echo "✓ Template autoinstall creato"

# Crea template GRUB corretto
echo ""
echo -e "${YELLOW}3. Creando template GRUB V8...${NC}"

cat > templates/grub.cfg.tpl << 'EOF'
set default="0"
set timeout=0
set timeout_style=hidden

menuentry "Ubuntu Autoinstall" {
    linux /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd /casper/initrd
}
EOF

echo "✓ Template GRUB creato"

# Crea script per generare ISO con hash dinamico
echo ""
echo -e "${YELLOW}4. Creando script generazione ISO con hash dinamico...${NC}"

cat > templates/create-autoinstall-iso.sh.tpl << 'EOF'
#!/bin/bash

set -e

VM_NAME="${vm_name}"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"
USERNAME="${username}"
PASSWORD="${password}"

echo "Creating autoinstall ISO for $VM_NAME..."

# Genera hash password dinamicamente
if command -v python3 &> /dev/null; then
    PASSWORD_HASH=$(python3 -c "import crypt; print(crypt.crypt('$PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))")
elif command -v mkpasswd &> /dev/null; then
    PASSWORD_HASH=$(echo "$PASSWORD" | mkpasswd -m sha-512 -s)
else
    SALT=$(openssl rand -base64 8 | tr -d '+=' | head -c 8)
    PASSWORD_HASH=$(openssl passwd -6 -salt "$SALT" "$PASSWORD")
fi

WORK_DIR="/tmp/iso-$VM_NAME-$$"
mkdir -p "$WORK_DIR/source-files"

# Extract Ubuntu ISO
7z -y x "${ubuntu_iso_path}" -o"$WORK_DIR/source-files" >/dev/null 2>&1

# Create autoinstall directory
mkdir -p "$WORK_DIR/source-files/autoinstall"

# Create user-data with dynamic hash
cat > "$WORK_DIR/source-files/autoinstall/user-data" << USERDATA
$(cat templates/autoinstall-user-data.yml.tpl | sed "s/\${ip_address}/$IP_ADDRESS/g" | sed "s/\${vm_name_lower}/${VM_NAME,,}/g" | sed "s/\${password_hash}/$PASSWORD_HASH/g" | sed "s/\${username}/$USERNAME/g")
USERDATA

# Create meta-data
echo "instance-id: $VM_NAME" > "$WORK_DIR/source-files/autoinstall/meta-data"

# Create GRUB config
cp templates/grub.cfg.tpl "$WORK_DIR/source-files/boot/grub/grub.cfg"

# Create ISO
cd "$WORK_DIR/source-files"
genisoimage -r -V "Ubuntu Autoinstall" \
    -cache-inodes -J -l -joliet-long \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "$(pwd)/$VM_NAME-autoinstall.iso" \
    . >/dev/null 2>&1

cd - >/dev/null
rm -rf "$WORK_DIR"

echo "✓ Created $VM_NAME-autoinstall.iso"
EOF

echo "✓ Script creazione ISO creato"

echo ""
echo -e "${GREEN}=== CONSOLIDAMENTO COMPLETATO ===${NC}"
echo ""
echo "File creati/aggiornati:"
echo "✓ templates/autoinstall-user-data.yml.tpl"
echo "✓ templates/grub.cfg.tpl"
echo "✓ templates/create-autoinstall-iso.sh.tpl"
echo ""
echo "Prossimi passi:"
echo "1. Aggiorna main.tf per usare i nuovi template"
echo "2. Test con: terraform plan"
echo "3. Deploy completo con: terraform apply"
echo ""
echo -e "${YELLOW}NOTA: Il main.tf deve essere aggiornato manualmente per:${NC}"
echo "- Usare il nuovo template create-autoinstall-iso.sh.tpl"
echo "- Rimuovere modifiche GRUB inline"
echo "- Usare hash password dinamico"
