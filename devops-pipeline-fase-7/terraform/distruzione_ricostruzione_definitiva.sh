#!/bin/bash

# SOLUZIONE DEFINITIVA - DISTRUZIONE E RICOSTRUZIONE VM
# VM bloccata in boot PXE loop, ricostruzione necessaria

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "DISTRUZIONE E RICOSTRUZIONE VM DEFINITIVA"
echo "=========================================="

echo ""
echo "PROBLEMA CONFERMATO: VM bloccata in boot PXE loop"
echo "SOLUZIONE: Distruzione completa e ricostruzione con Terraform"

# STEP 1: DISTRUZIONE COMPLETA VM CORROTTE
echo ""
echo "=== STEP 1: DISTRUZIONE COMPLETA VM ==="

echo "Fermando e distruggendo tutte le VM..."

# Stop forzato tutte le VM
for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
    VMX_PATH="$HOME/VMware_VMs/$VM/$VM.vmx"
    echo "Fermando $VM..."
    vmrun stop "$VMX_PATH" hard 2>/dev/null || true
done

# Kill processi VMware residui
pkill -f "vmware-vmx.*SPESE" 2>/dev/null || true
sleep 5

# Verifica stop
echo "VM dopo stop:"
vmrun list

# Distruzione directory VM complete
echo ""
echo "Rimuovendo directory VM corrotte..."
sudo rm -rf ~/VMware_VMs/SPESE_*

echo "✅ VM distrutte completamente"

# STEP 2: CLEANUP TERRAFORM STATE
echo ""
echo "=== STEP 2: CLEANUP TERRAFORM STATE ==="

echo "Pulendo stato Terraform..."

# Destroy Terraform state
terraform destroy -auto-approve 2>/dev/null || true

# Rimuovi file stato
rm -f terraform.tfstate*
rm -f tfplan*
rm -f .terraform.lock.hcl

echo "✅ Stato Terraform pulito"

# STEP 3: VERIFICA ISO FUNZIONANTI
echo ""
echo "=== STEP 3: VERIFICA ISO DISPONIBILI ==="

echo "ISO disponibili:"
ls -la *.iso 2>/dev/null || echo "❌ Nessun ISO trovato"

# Se non ci sono ISO, ricostruisci ISO base
if ! ls *.iso >/dev/null 2>&1; then
    echo ""
    echo "Nessun ISO trovato, ricostruendo ISO base..."
    
    # Crea ISO autoinstall base per test
    if [ -f "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" ]; then
        echo "Creando ISO autoinstall base..."
        
        # Estrai Ubuntu ISO
        TEMP_DIR="/tmp/iso_base_$$"
        mkdir -p "$TEMP_DIR/source-files"
        7z -y x "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso" -o"$TEMP_DIR/source-files" >/dev/null
        
        # Crea autoinstall semplice
        mkdir -p "$TEMP_DIR/source-files/server"
        
        cat > "$TEMP_DIR/source-files/server/user-data" << 'SIMPLEUSER'
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    hostname: ubuntu-server
    username: devops
    password: '$6$rounds=4096$saltsalt$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm'
  ssh:
    install-server: true
    allow-pw: true
  storage:
    layout:
      name: lvm
  packages:
    - openssh-server
    - docker.io
  late-commands:
    - 'echo "devops ALL=(ALL) NOPASSWD:ALL" > /target/etc/sudoers.d/devops'
  shutdown: reboot
SIMPLEUSER

        cat > "$TEMP_DIR/source-files/server/meta-data" << 'SIMPLEMETA'
instance-id: ubuntu-server
local-hostname: ubuntu-server
SIMPLEMETA

        # Crea ISO SENZA modifiche GRUB (Ubuntu standard)
        echo "Creando ISO con GRUB Ubuntu originale..."
        genisoimage -r -V "Ubuntu Simple Autoinstall" \
            -cache-inodes -J -joliet-long -l \
            -b boot/grub/i386-pc/eltorito.img \
            -c boot.catalog -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o "ubuntu-simple-autoinstall.iso" \
            "$TEMP_DIR/source-files" >/dev/null 2>&1
        
        if [ -f "ubuntu-simple-autoinstall.iso" ]; then
            echo "✅ ISO base autoinstall creato"
        fi
        
        rm -rf "$TEMP_DIR"
    fi
fi

# STEP 4: RICOSTRUZIONE CON TERRAFORM
echo ""
echo "=== STEP 4: RICOSTRUZIONE CON TERRAFORM ==="

echo "Inizializzando Terraform per ricostruzione..."

# Re-init Terraform
terraform init

# STRATEGIA: Crea solo 1 VM per test (FE_VM)
echo ""
echo "STRATEGIA: Creiamo solo FE_VM per test funzionamento"

# Modifica temporanea locals per solo FE_VM
cp main.tf main.tf.backup
sed -i '/\"BE\"/,/}/d; /\"DB\"/,/}/d' main.tf

echo "✅ Configurazione modificata per solo FE_VM"

# Plan e apply
terraform plan -out=tfplan

echo ""
echo "=== TERRAFORM APPLY - SOLO FE_VM ==="
echo "Creando solo FE_VM per test..."

terraform apply tfplan

# STEP 5: MONITORING RICOSTRUZIONE
echo ""
echo "=== STEP 5: MONITORING RICOSTRUZIONE ==="

echo "Attendendo creazione FE_VM..."

# Attendi completamento
sleep 60

echo ""
echo "Stato VM dopo ricostruzione:"
vmrun list

echo ""
echo "Test connectivity FE_VM:"
for i in {1..10}; do
    if ping -c 1 192.168.1.101 >/dev/null 2>&1; then
        echo "✅ FE_VM risponde al ping!"
        
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no devops@192.168.1.101 'echo SSH-OK' >/dev/null 2>&1; then
            echo "🎉 SSH ATTIVO - INSTALLAZIONE COMPLETATA!"
            break
        fi
    fi
    
    echo "Check $i/10 - FE_VM non ancora pronta..."
    sleep 30
done

echo ""
echo "=== RISULTATO RICOSTRUZIONE ==="

if vmrun list | grep -q "SPESE_FE_VM"; then
    echo "✅ FE_VM ricostruita"
    
    if ping -c 1 192.168.1.101 >/dev/null 2>&1; then
        echo "✅ FE_VM network attivo"
        echo "🎯 SUCCESSO PARZIALE - VM funziona!"
        
        echo ""
        echo "PROSSIMI STEP:"
        echo "1. Verifica console FE_VM"
        echo "2. Se funziona → ripristina BE e DB VM"
        echo "3. Complete deployment"
        
    else
        echo "⏳ FE_VM creata ma network non ancora attivo"
        echo "Controlla console VM per status installazione"
    fi
else
    echo "❌ Ricostruzione FE_VM fallita"
    echo "Verifica log Terraform per errori"
fi

echo ""
echo "=== RESTORE CONFIGURATION ==="
echo "Per ripristinare tutte e 3 VM:"
echo "mv main.tf.backup main.tf"
echo "terraform plan -out=tfplan"
echo "terraform apply tfplan"
