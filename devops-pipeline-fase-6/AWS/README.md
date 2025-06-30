# 🌩️ AWS DEPLOYMENT - CRM SYSTEM
## EC2 Free Tier (t2.micro) Deployment

---

## 🎯 STRATEGIA AWS

### 📊 AWS Free Tier Resources
```
EC2 t2.micro (750 ore/mese - 12 mesi gratuiti)
├── 1 vCPU
├── 1 GB RAM  
├── EBS storage fino a 30GB
├── Network I/O limitato
└── Elastic IP gratuito (se associato)
```

### 🏗️ Architettura Deployment
```
┌─────────────────────────────────────────────────┐
│                 AWS EC2 t2.micro                │
│                 (1 vCPU, 1GB RAM)               │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │            k3s Cluster                  │    │
│  │                                         │    │
│  │  ┌─────┐ ┌──────────┐ ┌─────────────┐   │    │
│  │  │ PG  │ │ Backend  │ │  Frontend   │   │    │
│  │  │128Mi│ │   64Mi   │ │    32Mi     │   │    │
│  │  │50m  │ │   25m    │ │    10m      │   │    │
│  │  └─────┘ └──────────┘ └─────────────┘   │    │
│  │                                         │    │
│  │  Total Used: ~450MB RAM, ~260m CPU     │    │
│  │  Available: ~550MB RAM, ~740m CPU      │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## 📋 COMPONENTI AWS

### 🔧 Script di Deployment
- `aws-setup.sh` - Setup iniziale EC2 e prerequisiti
- `aws-deploy.sh` - Deploy applicazione su AWS
- `aws-optimize.sh` - Ottimizzazioni specifiche t2.micro
- `aws-monitoring.sh` - Monitoring risorse e performance

### ☁️ Configurazioni AWS
- `ec2-userdata.sh` - Script di inizializzazione EC2
- `aws-k8s-config/` - Manifest ottimizzati per t2.micro
- `aws-profiles/` - Profili configurazione environment

### 🔄 Pipeline CI/CD
- `aws-pipeline.yml` - GitHub Actions per deploy AWS
- `terraform/` - Infrastructure as Code (opzionale)

---

## 🚀 QUICK START

### 1. Setup AWS EC2
```bash
# Crea istanza EC2 t2.micro
./AWS/aws-setup.sh create-instance

# Configura security groups e elastic IP
./AWS/aws-setup.sh configure-network
```

### 2. Deploy Applicazione
```bash
# Deploy ottimizzato per t2.micro
./AWS/aws-deploy.sh install

# Verifica deployment
./AWS/aws-deploy.sh status
```

### 3. Accesso Applicazione
```bash
# Frontend: http://YOUR-ELASTIC-IP:30002
# Backend API: http://YOUR-ELASTIC-IP:30003/api
```

---

## 💰 COSTI STIMATI

### Free Tier (12 mesi)
```
✅ EC2 t2.micro: $0/mese (750 ore free)
✅ EBS 30GB: $0/mese  
✅ Data transfer: $0/mese (15GB free)
✅ Elastic IP: $0/mese (se associato)
────────────────────────────────
Total: $0/mese
```

### Post Free Tier
```
💰 EC2 t2.micro: ~$8.50/mese
💰 EBS 30GB: ~$2.40/mese  
💰 Data transfer: ~$1.00/mese
💰 Elastic IP: $0/mese (se associato)
────────────────────────────────
Total: ~$12/mese
```

---

## 🔧 OTTIMIZZAZIONI t2.micro

### Resource Allocation
```yaml
# PostgreSQL (ottimizzato)
resources:
  requests:
    memory: "128Mi"  # 12.5% RAM
    cpu: "50m"       # 5% CPU
  limits:
    memory: "256Mi"  # 25% RAM
    cpu: "200m"      # 20% CPU

# Backend (minimal)
resources:
  requests:
    memory: "64Mi"   # 6% RAM
    cpu: "25m"       # 2.5% CPU
  limits:
    memory: "128Mi"  # 12.5% RAM
    cpu: "100m"      # 10% CPU

# Frontend (lightweight)
resources:
  requests:
    memory: "32Mi"   # 3% RAM
    cpu: "10m"       # 1% CPU
  limits:
    memory: "64Mi"   # 6% RAM
    cpu: "50m"       # 5% CPU
```

### Performance Tuning
```bash
# PostgreSQL ottimizzazioni
shared_buffers = 32MB
max_connections = 20
work_mem = 1MB
effective_cache_size = 128MB

# Swap configuration
echo 'vm.swappiness=10' >> /etc/sysctl.conf

# Kernel tuning per low memory
echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
```

---

## 📊 MONITORING

### Resource Monitoring
```bash
# Verifica utilizzo risorse
./AWS/aws-monitoring.sh resources

# Monitor performance applicazione
./AWS/aws-monitoring.sh performance

# Alert su memory pressure
./AWS/aws-monitoring.sh alerts
```

### CloudWatch Integration
```bash
# Setup CloudWatch agent
./AWS/aws-monitoring.sh setup-cloudwatch

# Custom metrics
./AWS/aws-monitoring.sh custom-metrics
```

---

## 🔄 SCALING OPTIONS

### Vertical Scaling
```bash
# Upgrade a t3.small (2GB RAM, 2 vCPU)
./AWS/aws-setup.sh scale-vertical t3.small

# Update resource limits
./AWS/aws-optimize.sh update-resources
```

### Horizontal Scaling
```bash
# Multi-instance con Load Balancer
./AWS/aws-setup.sh scale-horizontal

# Auto Scaling Group setup
./AWS/aws-setup.sh setup-asg
```

---

## 🛡️ SECURITY

### Security Groups
```yaml
# HTTP/HTTPS access
- Port: 80, 443
  Source: 0.0.0.0/0
  Description: Web traffic

# Application ports
- Port: 30002, 30003
  Source: 0.0.0.0/0  
  Description: CRM application

# SSH access
- Port: 22
  Source: YOUR-IP/32
  Description: SSH access
```

### Best Practices
```bash
# Update sistema automatici
sudo apt update && sudo apt upgrade -y

# Firewall configuration
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 30002,30003/tcp

# SSL/TLS (Let's Encrypt)
./AWS/aws-setup.sh setup-ssl
```

---

## 🔄 BACKUP & RECOVERY

### EBS Snapshots
```bash
# Snapshot automatici
./AWS/aws-setup.sh setup-snapshots

# Backup scheduling
./AWS/aws-setup.sh schedule-backups
```

### Database Backup
```bash
# PostgreSQL backup su S3
./AWS/aws-monitoring.sh backup-database

# Restore da backup
./AWS/aws-monitoring.sh restore-database
```

---

## 🔗 INTEGRATION

### DEV_VM → AWS Migration
```bash
# Export configurazione DEV_VM
./deploy-k8s.sh export-config

# Import e adapt per AWS
./AWS/aws-deploy.sh import-config

# Test migration
./AWS/aws-deploy.sh test-migration
```

### CI/CD Pipeline
```yaml
# GitHub Actions
on:
  push:
    branches: [main]
    paths: ['devops-pipeline-fase-6/**']

jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to AWS
        run: |
          ./AWS/aws-deploy.sh deploy
```

---

## 📞 TROUBLESHOOTING

### Memory Issues
```bash
# Monitor memory pressure
watch -n 1 free -m

# Check OOM killer logs
dmesg | grep -i "killed process"

# Optimize swap usage
./AWS/aws-optimize.sh optimize-memory
```

### Performance Issues
```bash
# CPU monitoring
top -p $(pgrep k3s)

# Disk I/O monitoring  
iostat -x 1

# Network monitoring
nethogs
```

### Common Fixes
```bash
# Restart k3s service
sudo systemctl restart k3s

# Clear container cache
sudo k3s crictl rmi --prune

# Optimize database
./AWS/aws-optimize.sh optimize-database
```

---

## 🎯 NEXT STEPS

1. **Setup AWS Account**: Configurazione iniziale free tier
2. **Create EC2 Instance**: Deploy con script automatizzati
3. **Install Application**: Deploy CRM system ottimizzato
4. **Configure Monitoring**: Setup alerting e metrics
5. **Test & Optimize**: Performance tuning e troubleshooting
6. **Plan Scaling**: Strategie per crescita futura

**Pronto per iniziare il deployment AWS!** 🚀
