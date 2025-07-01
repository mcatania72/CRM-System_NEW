# LOCAL BUILD + SSH DEPLOY STRATEGY

## 🎯 STRATEGIA COMPLETA

### **FASE 1: Pre-build su DEV_VM (24GB RAM)**
- Build TypeScript backend → `dist/app.js`
- Build React frontend → `dist/`
- Creazione package deployment ottimizzato
- Test locale per validare build

### **FASE 2: SSH Deploy Automatico**
- SSH dalla DEV_VM → AWS EC2 
- Transfer artifacts via SCP
- Deploy Docker Compose su AWS
- Setup automatico servizi

### **FASE 3: Esclusivamente AWS**
- Test funzionalità complete
- Monitoring performance t2.micro
- Debugging e ottimizzazione

## 🛠️ **SETUP DEV_VM per SSH**

### **Prerequisites DEV_VM:**
```bash
# 1. SSH client (già presente su Ubuntu)
sudo apt update && sudo apt install openssh-client

# 2. Node.js e npm per build
node --version  # v18+
npm --version   # v8+

# 3. AWS keypair file (.pem) 
# Scarica da AWS Console → EC2 → Key Pairs

# 4. IP pubblico AWS EC2
# Trova in AWS Console → EC2 → Instances
```

### **File necessari:**
- AWS keypair (`.pem`) con permessi 600
- IP pubblico dell'istanza EC2
- Accesso internet dalla DEV_VM

## 🚀 **UTILIZZO SCRIPT**

### **Esecuzione completa:**
```bash
# Su DEV_VM
cd ~/Claude/devops-pipeline-fase-6/AWS/build-and-deploy
chmod +x local-build-ssh-deploy.sh
./local-build-ssh-deploy.sh
```

### **Lo script chiederà:**
- IP pubblico AWS EC2
- Percorso chiave AWS (.pem)

### **Processo automatico:**
1. ✅ Verifica prerequisites
2. ✅ Build backend TypeScript
3. ✅ Build frontend React  
4. ✅ Crea package deployment
5. ✅ Test connessione SSH
6. ✅ Transfer package su AWS
7. ✅ Deploy Docker Compose
8. ✅ Test applicazione
9. ✅ Setup monitoring

## 📊 **OUTPUT ATTESO**

### **URLs finali:**
- Frontend: `http://IP_AWS:30002`
- Backend API: `http://IP_AWS:30003/api`

### **Login default:**
- Email: `admin@crm.local`
- Password: `admin123`

## 🔧 **TROUBLESHOOTING**

### **SSH connection failed:**
```bash
# Verifica permessi chiave
chmod 600 /path/to/aws-key.pem

# Test manuale
ssh -i /path/to/aws-key.pem ubuntu@IP_AWS
```

### **Build failed:**
```bash
# Verifica Node.js
node --version  # deve essere v18+
npm --version   # deve essere v8+

# Clean e retry
rm -rf backend/node_modules frontend/node_modules
npm cache clean --force
```

### **Deploy failed su AWS:**
```bash
# SSH su AWS e debug
ssh -i aws-key.pem ubuntu@IP_AWS
cd /home/ubuntu/crm-deploy
docker-compose logs
```

## 📈 **VANTAGGI STRATEGIA**

### **Build Locale (DEV_VM):**
- ✅ 24GB RAM → No memory issues
- ✅ Build veloce e stabile
- ✅ Debug locale facile
- ✅ Artifacts ottimizzati

### **Deploy AWS (t2.micro):**
- ✅ Solo runtime, no build
- ✅ Memoria risparmiata
- ✅ Deploy veloce
- ✅ $0 costi (Free Tier)

### **Processo Automatizzato:**
- ✅ One-command deployment
- ✅ Error handling completo
- ✅ Test automatici
- ✅ Monitoring setup

## 🎉 **RISULTATO FINALE**

CRM completo funzionante su AWS EC2 t2.micro Free Tier con:
- Frontend React servito da Nginx
- Backend TypeScript/Express con TypeORM
- Database PostgreSQL 16
- Docker Compose orchestration
- Zero costi per 12 mesi
