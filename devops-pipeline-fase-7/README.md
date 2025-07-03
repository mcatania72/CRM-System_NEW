# 🚀 FASE 7 - Creazione VM con Terraform e Ubuntu Autoinstall

## 📋 Panoramica
Questa fase automatizza la creazione di 3 VM VMware con Ubuntu 22.04 usando Terraform e autoinstall.

### VM Create:
- **SPESE_FE_VM** (192.168.1.101) - Frontend/Master Kubernetes
- **SPESE_BE_VM** (192.168.1.102) - Backend/Worker Kubernetes  
- **SPESE_DB_VM** (192.168.1.103) - Database/Worker Kubernetes

## 🛠️ Prerequisiti

### Software richiesto:
- VMware Workstation Pro
- Terraform >= 1.0
- Ubuntu 22.04 Server ISO in `/home/devops/images/`
- Strumenti: `genisoimage`, `p7zip-full`, `vmware-vdiskmanager`

### Risorse minime:
- RAM: 12GB disponibili (4GB per VM)
- Disco: 80GB liberi
- CPU: 6+ cores

## 🚀 Deploy Completo

```bash
# 1. Posizionamento
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

# 2. Inizializzazione Terraform
terraform init

# 3. Deploy automatico (tempo: ~37 minuti)
terraform apply -auto-approve
```

### Fasi del deploy:
1. **0-3 min**: Creazione ISO autoinstall personalizzati
2. **3-6 min**: Creazione VM e avvio
3. **6-36 min**: Installazione Ubuntu automatica
4. **36-37 min**: Cleanup ISO e finalizzazione

## 🔧 Gestione VM

### Verifica stato:
```bash
# Lista VM attive
vmrun list

# Verifica connettività
ping 192.168.1.101  # FE
ping 192.168.1.102  # BE
ping 192.168.1.103  # DB

# Test SSH (password: devops)
ssh devops@192.168.1.101
ssh devops@192.168.1.102
ssh devops@192.168.1.103
```

### Stop tutte le VM:
```bash
# Stop ordinato
vmrun stop ~/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx soft
vmrun stop ~/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx soft
vmrun stop ~/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx soft

# Oppure stop forzato
vmrun stop ~/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx hard
vmrun stop ~/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx hard
vmrun stop ~/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx hard
```

### Start tutte le VM:
```bash
# Avvio VM
vmrun start ~/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx
vmrun start ~/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx
vmrun start ~/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx

# Verifica avvio
vmrun list
```

### Script helper per gestione:
```bash
# Crea script stop-all-vms.sh
cat > ~/stop-all-vms.sh << 'EOF'
#!/bin/bash
echo "Stopping all SPESE VMs..."
vmrun stop ~/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx soft
vmrun stop ~/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx soft
vmrun stop ~/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx soft
echo "Done. Current VMs:"
vmrun list
EOF
chmod +x ~/stop-all-vms.sh

# Crea script start-all-vms.sh
cat > ~/start-all-vms.sh << 'EOF'
#!/bin/bash
echo "Starting all SPESE VMs..."
vmrun start ~/VMware_VMs/SPESE_FE_VM/SPESE_FE_VM.vmx
vmrun start ~/VMware_VMs/SPESE_BE_VM/SPESE_BE_VM.vmx
vmrun start ~/VMware_VMs/SPESE_DB_VM/SPESE_DB_VM.vmx
echo "Done. Current VMs:"
vmrun list
EOF
chmod +x ~/start-all-vms.sh
```

## 🗑️ Pulizia e Rimozione

### Destroy completo con Terraform:
```bash
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform
terraform destroy -auto-approve
```

### Pulizia manuale (se necessario):
```bash
# Stop VM
vmrun list | grep SPESE | while read vm; do
    vmrun stop "$vm" hard
done

# Rimuovi directory VM
sudo rm -rf ~/VMware_VMs/SPESE_*

# Rimuovi file temporanei
rm -f *.iso create-*.sh
rm -rf .terraform* terraform.tfstate*
```

## 🐛 Troubleshooting

### Problema: "Inconsistent dependency lock file"
```bash
rm -f .terraform.lock.hcl
terraform init
```

### Problema: VM non si avvia
```bash
# Verifica servizi VMware
sudo systemctl status vmware
sudo systemctl restart vmware
```

### Problema: Autoinstall fallisce
- Verificare che l'ISO Ubuntu sia presente in `/home/devops/images/`
- Controllare spazio disco disponibile
- Verificare console VM per errori specifici

### Problema: SSH non funziona dopo installazione
```bash
# Verifica che la VM sia completamente avviata (15-20 min)
# Controlla IP e connectivity
ping 192.168.1.10X
# Password di default: devops
```

## 📊 Risorse Create

### File Terraform:
- `main.tf` - Configurazione principale
- `terraform.tfstate` - Stato Terraform
- `.terraform.lock.hcl` - Lock providers

### Script generati:
- `create-iso-{FE,BE,DB}.sh` - Script creazione ISO
- `create-vm-{FE,BE,DB}.sh` - Script creazione VM

### ISO Autoinstall:
- `SPESE_FE_VM-autoinstall.iso` (rimosso dopo deploy)
- `SPESE_BE_VM-autoinstall.iso` (rimosso dopo deploy)
- `SPESE_DB_VM-autoinstall.iso` (rimosso dopo deploy)

### Directory VM:
- `~/VMware_VMs/SPESE_FE_VM/`
- `~/VMware_VMs/SPESE_BE_VM/`
- `~/VMware_VMs/SPESE_DB_VM/`

## ⏱️ Tempistiche

- **Deploy completo**: ~37 minuti
- **Destroy completo**: ~2 minuti
- **Start VM**: ~30 secondi per VM
- **Stop VM**: ~10 secondi per VM

## 🔐 Credenziali Default

- **Username**: devops
- **Password**: devops
- **Sudo**: NOPASSWD configurato

## 📝 Note Importanti

1. **Timeout**: Gli script aspettano max 30 minuti per l'installazione, poi proseguono
2. **Cleanup ISO**: Gli ISO vengono rimossi automaticamente dopo il timeout per risparmiare spazio
3. **No SSH check**: Gli script non verificano SSH per evitare blocchi su password
4. **Exit sempre 0**: Gli script terminano sempre con successo per non bloccare Terraform

## 🎯 Prossimi Passi

Dopo il deploy delle VM:
1. Verificare accesso SSH a tutte le VM
2. Procedere con installazione Kubernetes (Fase 8)
3. Deploy applicazione CRM (Fase 9)

---
*Documentazione aggiornata: Gennaio 2025*
