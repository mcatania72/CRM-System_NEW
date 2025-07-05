#!/bin/bash

set -e

VM_NAME="${vm_name}"
IP_ADDRESS="${ip_address}"
VM_ROLE="${vm_role}"
USERNAME="${username}"
PASSWORD="${password}"

echo "Creating autoinstall ISO for $VM_NAME (FASE 7.1 - PLAINTEXT TEST)..."

WORK_DIR="/tmp/iso-$VM_NAME-$$"
mkdir -p "$WORK_DIR/source-files"

# Extract Ubuntu ISO
7z -y x "${ubuntu_iso_path}" -o"$WORK_DIR/source-files" >/dev/null 2>&1

# Create autoinstall directory
mkdir -p "$WORK_DIR/source-files/autoinstall"

# SSH public key per zero-touch (se disponibile)
SSH_PUB_KEY="${ssh_public_key}"

# Create user-data - PASSWORD IN CHIARO PER TEST!
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
    hostname: $(echo $VM_NAME | tr '[:upper:]' '[:lower:]' | sed 's/_vm//')
    password: $PASSWORD
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
    - docker.io
  late-commands:
    # FASE 7 - Comandi base (funzionanti)
    - echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/$USERNAME
    - chmod 440 /target/etc/sudoers.d/$USERNAME
    
    # FASE 7.1 - SEMPLIFICATI
    # Docker è già installato dai packages, abilitiamolo
    - curtin in-target --target=/target -- systemctl enable docker
    
    # SSH directory
    - curtin in-target --target=/target -- mkdir -p /home/$USERNAME/.ssh
    - curtin in-target --target=/target -- chmod 700 /home/$USERNAME/.ssh
    
    # SSH authorized_keys (se abbiamo la chiave)
%{ if ssh_public_key != "" }
    - echo '${ssh_public_key}' > /target/home/$USERNAME/.ssh/authorized_keys
    - curtin in-target --target=/target -- chmod 600 /home/$USERNAME/.ssh/authorized_keys
%{ endif }
    
    # Fix ownership
    - curtin in-target --target=/target -- chown -R $USERNAME:$USERNAME /home/$USERNAME
    
    # Docker daemon config - METODO SEMPLICE
    - curtin in-target --target=/target -- mkdir -p /etc/docker
    - echo '{"insecure-registries":["192.168.1.101:5000"]}' > /target/etc/docker/daemon.json
    
    # Debug info
    - echo "User $USERNAME created with plaintext password for testing" > /target/var/log/autoinstall-debug.log
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
genisoimage -r -V "Ubuntu 7.1 Plain" \
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

echo "✓ Created $VM_NAME-autoinstall.iso (FASE 7.1 - PLAINTEXT TEST)"
echo "  Username: $USERNAME"
echo "  Password: [plaintext - for testing only]"
echo "  SSH key: $SSH_PUB_KEY" | head -c 50
echo "..."
ls -la "$ORIGINAL_DIR/$VM_NAME-autoinstall.iso"
