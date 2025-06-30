# 🌩️ AWS DEPLOYMENT QUICK START
## Guida rapida per deploy CRM su EC2 Free Tier

---

## 🚀 SETUP INIZIALE (Una sola volta)

### 1. Prerequisiti
```bash
# Installa AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configura AWS CLI
aws configure
# Inserisci: Access Key, Secret Key, Region (us-east-1), Output (json)
```

### 2. Setup Completo (Automatico)
```bash
cd devops-pipeline-fase-6/AWS
chmod +x aws-manager.sh

# Setup completo: infrastruttura + deploy + monitoring
./aws-manager.sh setup
```

**Tempo stimato**: 10-15 minuti  
**Risultato**: CRM funzionante su AWS EC2 t2.micro

---

## 🎯 ACCESSO APPLICAZIONE

Dopo il setup completo:
```
🌐 Frontend:     http://YOUR-IP:30002
🔌 Backend API:  http://YOUR-IP:30003/api
🔑 Login:        admin@crm.local / admin123
```

---

## 📋 COMANDI QUOTIDIANI

### Status Sistema
```bash
./aws-manager.sh status           # Status completo
./aws-manager.sh monitor health   # Health checks
./aws-manager.sh monitor resources # Risorse sistema
```

### Deploy Applicazione
```bash
./aws-manager.sh deploy           # Deploy veloce
```

### Backup Database
```bash
./aws-manager.sh backup backup    # Crea backup
./aws-manager.sh backup restore crm_backup_*.sql.gz # Restore
```

### Ottimizzazione
```bash
./aws-manager.sh optimize         # Ottimizza performance
```

---

## 🔧 TROUBLESHOOTING

### Problemi Comuni
```bash
# Memoria insufficiente
./aws-manager.sh optimize

# Pod non avviano
./aws-manager.sh monitor health

# Performance lente
./aws-manager.sh monitor performance

# Accesso SSH
ssh -i crm-key-pair.pem ubuntu@YOUR-IP
```

### Reset Completo
```bash
./aws-manager.sh cleanup          # Elimina tutto
./aws-manager.sh setup            # Ricrea da zero
```

---

## 💰 COSTI

### Free Tier (12 mesi)
- **EC2 t2.micro**: Gratuito (750 ore/mese)
- **Storage**: Gratuito (30GB)
- **Traffico**: Gratuito (15GB/mese)
- **Total**: **$0/mese**

### Post Free Tier
- **Total**: **~$12/mese**

---

## 📈 SCALING

### Upgrade Istanza
```bash
# Scale a t3.small (2GB RAM, 2 vCPU)
./aws-manager.sh scale t3.small

# Scale a t3.medium (4GB RAM, 2 vCPU)
./aws-manager.sh scale t3.medium
```

---

## 🆘 SUPPORTO

### Log Files
```bash
# System logs
sudo journalctl -u k3s -f

# Application logs
sudo k3s kubectl logs -f deployment/backend -n crm-system
```

### Debug Scripts
```bash
./aws-manager.sh aws-monitoring health
./aws-manager.sh aws-setup verify
./aws-manager.sh aws-deploy status
```

---

## 🎉 SUCCESS!

Se tutto funziona, dovresti vedere:
- ✅ Frontend carica su porta 30002
- ✅ Login funziona con admin@crm.local
- ✅ API risponde su porta 30003
- ✅ Database PostgreSQL connesso

**Il tuo CRM è ora live su AWS!** 🚀
