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

# Create user-data - MINIMALE COME V8
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
  late-commands:
    - echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/$USERNAME
    - chmod 440 /target/etc/sudoers.d/$USERNAME
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
genisoimage -r -V "Ubuntu Autoinstall" \
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

echo "✓ Created $VM_NAME-autoinstall.iso"
ls -la "$ORIGINAL_DIR/$VM_NAME-autoinstall.iso"
