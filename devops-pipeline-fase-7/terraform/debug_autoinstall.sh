#!/bin/bash
# Debug script per verificare creazione ISO autoinstall

echo "=== DEBUG AUTOINSTALL ISO CREATION ==="

# 1. Verifica prerequisiti
echo "=== PREREQUISITI ==="
which genisoimage || echo "❌ genisoimage mancante - installing..."
which 7z || echo "❌ p7zip-full mancante - installing..."

# Installa se mancanti
if ! which genisoimage >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y genisoimage
fi

if ! which 7z >/dev/null; then
    sudo apt-get update  
    sudo apt-get install -y p7zip-full
fi

# 2. Verifica spazio disco
echo "=== SPAZIO DISCO ==="
df -h /tmp
df -h ~/CRM-Fase7/devops-pipeline-fase-7/terraform

# 3. Test creazione manuale ISO autoinstall
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== TEST CREAZIONE ISO MANUALE ==="

# Test per FE VM
VM_NAME="SPESE_FE_VM"
IP_ADDRESS="192.168.1.101"
VM_ROLE="master"

# Crea directory temporanea
ISO_TEMP_DIR="/tmp/${VM_NAME}-autoinstall"
mkdir -p "$ISO_TEMP_DIR"

echo "Creando user-data per $VM_NAME..."
# Genera user-data
sed -e "s/\${vm_name}/$VM_NAME/g" \
    -e "s/\${ip_address}/$IP_ADDRESS/g" \
    -e "s/\${vm_role}/$VM_ROLE/g" \
    templates/autoinstall-user-data.yml.tpl > "$ISO_TEMP_DIR/user-data"

echo "Creando meta-data per $VM_NAME..."  
# Genera meta-data
sed -e "s/\${vm_name}/$VM_NAME/g" \
    -e "s/\${ip_address}/$IP_ADDRESS/g" \
    templates/autoinstall-meta-data.yml.tpl > "$ISO_TEMP_DIR/meta-data"

echo "File generati:"
ls -la "$ISO_TEMP_DIR/"
echo "--- user-data content ---"
head -20 "$ISO_TEMP_DIR/user-data"
echo "--- meta-data content ---"
cat "$ISO_TEMP_DIR/meta-data"

echo "Creando ISO autoinstall per $VM_NAME..."
# Crea ISO cloud-init
genisoimage -output "${VM_NAME}-autoinstall.iso" \
    -volid cidata \
    -joliet \
    -rock \
    "$ISO_TEMP_DIR/user-data" \
    "$ISO_TEMP_DIR/meta-data"

if [ -f "${VM_NAME}-autoinstall.iso" ]; then
    echo "✅ ISO creato con successo: ${VM_NAME}-autoinstall.iso"
    ls -la "${VM_NAME}-autoinstall.iso"
else
    echo "❌ Fallimento creazione ISO"
fi

# Cleanup
rm -rf "$ISO_TEMP_DIR"

echo "=== VERIFICA TERRAFORM NULL_RESOURCE ==="
echo "Verifico perché il null_resource.create_autoinstall_iso fallisce..."

# Mostra dettagli null_resource dalla configurazione
echo "Controllando main.tf per null_resource..."
grep -A 20 "resource \"null_resource\" \"create_autoinstall_iso\"" main.tf || echo "❌ null_resource non trovato in main.tf"

echo "=== DEBUG COMPLETATO ==="
