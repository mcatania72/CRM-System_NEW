#!/bin/bash

# FIX MAIN.TF CORROTTO + RICOSTRUZIONE PULITA
# La modifica sed ha danneggiato la sintassi

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "FIX MAIN.TF CORROTTO + RICOSTRUZIONE"
echo "=========================================="

echo ""
echo "PROBLEMA: Modifica sed ha corrotto main.tf"
echo "SOLUZIONE: Ripristino main.tf e strategia diversa"

# STEP 1: RIPRISTINO MAIN.TF
echo ""
echo "=== STEP 1: RIPRISTINO MAIN.TF ==="

if [ -f "main.tf.backup" ]; then
    echo "Ripristinando main.tf dal backup..."
    cp main.tf.backup main.tf
    echo "✅ main.tf ripristinato"
else
    echo "❌ Backup non trovato, ripristinando da git..."
    cd ~/CRM-Fase7
    git checkout main.tf 2>/dev/null || echo "❌ Git checkout fallito"
    cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform
fi

# Verifica sintassi Terraform
echo ""
echo "Verificando sintassi Terraform..."
if terraform validate; then
    echo "✅ main.tf sintassi corretta"
else
    echo "❌ main.tf ancora corrotto"
    
    # Pull fresh da git
    echo "Ripristinando da git repository..."
    cd ~/CRM-Fase7
    git reset --hard HEAD
    git pull origin main
    cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform
    
    # Re-test
    terraform validate && echo "✅ main.tf corretto da git" || echo "❌ Problema persistente"
fi

# STEP 2: STRATEGIA ALTERNATIVA - TARGET SPECIFICO
echo ""
echo "=== STEP 2: STRATEGIA TARGET SPECIFICO ==="

echo "Invece di modificare main.tf, usiamo terraform target"
echo "Creiamo solo le risorse per FE_VM"

# Lista target per FE_VM
echo ""
echo "Target Terraform per FE_VM:"
echo "  - local_file.autoinstall_user_data[\"FE\"]"
echo "  - local_file.autoinstall_meta_data[\"FE\"]" 
echo "  - null_resource.create_autoinstall_iso[\"FE\"]"
echo "  - local_file.vm_creation_script[\"FE\"]"
echo "  - null_resource.create_vms[\"FE\"]"

# STEP 3: TERRAFORM INIT E PLAN SOLO FE
echo ""
echo "=== STEP 3: TERRAFORM PLAN SOLO FE_VM ==="

# Re-init se necessario
terraform init

echo ""
echo "Planning solo risorse FE_VM..."

# Plan solo per FE_VM usando target
terraform plan \
  -target='local_file.autoinstall_user_data["FE"]' \
  -target='local_file.autoinstall_meta_data["FE"]' \
  -target='null_resource.create_autoinstall_iso["FE"]' \
  -target='local_file.vm_creation_script["FE"]' \
  -target='null_resource.create_vms["FE"]' \
  -out=tfplan-fe

if [ $? -eq 0 ]; then
    echo "✅ Plan FE_VM completato con successo"
    
    # STEP 4: APPLY SOLO FE_VM
    echo ""
    echo "=== STEP 4: APPLY SOLO FE_VM ==="
    
    echo "Applicando solo risorse FE_VM..."
    terraform apply tfplan-fe
    
    APPLY_RESULT=$?
    
else
    echo "❌ Plan FE_VM fallito"
    echo ""
    echo "Errori Terraform:"
    terraform validate
    exit 1
fi

# STEP 5: VERIFICA RISULTATO
echo ""
echo "=== STEP 5: VERIFICA RISULTATO ==="

if [ $APPLY_RESULT -eq 0 ]; then
    echo "✅ Apply FE_VM completato"
    
    echo ""
    echo "File creati:"
    ls -la *.iso 2>/dev/null || echo "❌ Nessun ISO creato"
    ls -la create-vm-FE.sh 2>/dev/null || echo "❌ Script FE non creato"
    
    echo ""
    echo "VM Status:"
    vmrun list
    
    echo ""
    echo "Se FE_VM creata, attendiamo installazione..."
    
    # Monitoring FE_VM
    echo "Monitoring FE_VM per 5 minuti..."
    for i in {1..10}; do
        if ping -c 1 192.168.1.101 >/dev/null 2>&1; then
            echo "✅ FE_VM risponde! (check $i/10)"
            
            if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no devops@192.168.1.101 'echo SSH-OK' >/dev/null 2>&1; then
                echo "🎉 SSH ATTIVO - FE_VM COMPLETAMENTE FUNZIONANTE!"
                
                echo ""
                echo "=== SUCCESSO PARZIALE! ==="
                echo "FE_VM installata e funzionante"
                echo "Per creare BE e DB VM:"
                echo "terraform plan -out=tfplan-all"
                echo "terraform apply tfplan-all"
                
                exit 0
            fi
        else
            echo "Check $i/10 - FE_VM non ancora pronta..."
        fi
        
        sleep 30
    done
    
    echo ""
    echo "FE_VM creata ma non ancora risponde"
    echo "Controlla console VMware per status"
    
else
    echo "❌ Apply FE_VM fallito"
    echo "Controlla errori Terraform sopra"
fi

echo ""
echo "=== NEXT STEPS ==="
echo "Se FE_VM funziona:"
echo "  terraform plan -out=tfplan-complete"
echo "  terraform apply tfplan-complete"
echo ""
echo "Se FE_VM non funziona:"
echo "  Controlla console VMware"
echo "  Verifica log installazione"
