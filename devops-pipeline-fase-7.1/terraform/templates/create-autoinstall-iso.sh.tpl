#!/bin/bash

set -e

VM_NAME="${vm_name}"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"
USERNAME="${username}"
PASSWORD="${password}"

echo "Creating autoinstall ISO for $VM_NAME (FASE 7.1)..."

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

# SSH public key per zero-touch (verrà generata da terraform)
SSH_PUB_KEY="${ssh_public_key}"

# Create user-data - FASE 7.1 con Docker e SSH keys
cat > "$WORK_DIR/source-files/autoinstall/user-data" << USERDATA
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
          - $IP_ADDRESS/24
        gateway4: 192.168.1.1
        nameservers:
          addresses: [8.8.8.8, 8.8.4.4]
    version: 2
  identity:
    hostname: $${VM_NAME,,}
    password: '$PASSWORD_HASH'
    username: $USERNAME
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
    - ca-certificates
    - gnupg
    - lsb-release
    - apt-transport-https
    - software-properties-common
  late-commands:
    # FASE 7 - Comandi base (funzionanti)
    - echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/$USERNAME
    - chmod 440 /target/etc/sudoers.d/$USERNAME
    
    # FASE 7.1 - Aggiunte incrementali per Docker
    # Prepara per Docker
    - curtin in-target --target=/target -- mkdir -p /etc/apt/keyrings
    - curtin in-target --target=/target -- sh -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    - curtin in-target --target=/target -- sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list'
    
    # Installa Docker
    - curtin in-target --target=/target -- apt-get update
    - curtin in-target --target=/target -- apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Abilita Docker
    - curtin in-target --target=/target -- systemctl enable docker
    
    # IMPORTANTE: Non facciamo usermod qui, lo faremo con systemd service post-boot
    # Crea servizio per setup Docker group post-boot
    - |
      cat > /target/etc/systemd/system/docker-user-setup.service << 'EOF'
      [Unit]
      Description=Setup Docker user group
      After=docker.service
      Wants=docker.service
      
      [Service]
      Type=oneshot
      ExecStart=/bin/bash -c 'groupadd -f docker && usermod -aG docker $USERNAME && touch /var/lib/docker-user-setup.done'
      RemainAfterExit=yes
      
      [Install]
      WantedBy=multi-user.target
      EOF
    - curtin in-target --target=/target -- systemctl enable docker-user-setup.service
    
    # FASE 7.1 - SSH Keys setup
    - curtin in-target --target=/target -- mkdir -p /home/$USERNAME/.ssh
    - curtin in-target --target=/target -- chmod 700 /home/$USERNAME/.ssh
    # Se abbiamo una chiave pubblica, aggiungila
%{ if ssh_public_key != "" }
    - echo '$${SSH_PUB_KEY}' >> /target/home/$USERNAME/.ssh/authorized_keys
    - curtin in-target --target=/target -- chmod 600 /home/$USERNAME/.ssh/authorized_keys
%{ endif }
    - curtin in-target --target=/target -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    
    # FASE 7.1 - Configura registry locale
%{ if vm_role == "master" }
    # Su master, prepara per registry
    - curtin in-target --target=/target -- mkdir -p /var/lib/docker-registry
%{ endif }
    # Su tutte le VM, prepara daemon.json per registry insecure
    - |
      cat > /target/etc/docker/daemon.json << 'EOF'
      {
        "insecure-registries": ["192.168.1.101:5000"]
      }
      EOF
USERDATA

# Create meta-data
echo "instance-id: $VM_NAME" > "$WORK_DIR/source-files/autoinstall/meta-data"

# Create GRUB config - ZERO TOUCH
cat > "$WORK_DIR/source-files/boot/grub/grub.cfg" << 'GRUBCFG'
set default="0"
set timeout=0
set timeout_style=hidden

menuentry "Ubuntu Autoinstall" {
    linux /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd /casper/initrd
}
GRUBCFG

# Save current directory
ORIGINAL_DIR="$(pwd)"

# Create ISO
cd "$WORK_DIR/source-files"
genisoimage -r -V "Ubuntu 7.1" \
    -cache-inodes -J -l -joliet-long \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "$VM_NAME-autoinstall.iso" \
    . >/dev/null 2>&1

# Copy ISO to original terraform directory
cp "$VM_NAME-autoinstall.iso" "$ORIGINAL_DIR/" || { echo "Failed to copy ISO"; exit 1; }

cd - >/dev/null
rm -rf "$WORK_DIR"

echo "✓ Created $VM_NAME-autoinstall.iso (FASE 7.1)"
ls -la "$ORIGINAL_DIR/$VM_NAME-autoinstall.iso"
