# 📚 DOCUMENTAZIONE FASE 6 - CRM SYSTEM
## Port-Forward Strutturale per Accesso Esterno

---

## 🎯 ARCHITETTURA DEFINITIVA

### 📊 Schema Architetturale
```
┌─────────────────┐    ┌─────────────────────────────────────────────┐
│   HOST WINDOWS  │    │              DEV_VM (192.168.1.29)          │
│                 │    │                                             │
│   Browser       │◄──►│  Port-Forward   ┌─────────────────────────┐ │
│   30002/30003   │    │  30002 ──────►  │    Kubernetes Cluster   │ │
│                 │    │  30003 ──────►  │                         │ │
└─────────────────┘    │                 │  ┌─────┐ ┌──────┐ ┌────┐ │ │
                       │                 │  │ PG  │ │ BE   │ │ FE │ │ │
                       │                 │  │Pod  │ │ Pod  │ │Pod │ │ │
                       │                 │  └─────┘ └──────┘ └────┘ │ │
                       │                 │                         │ │
                       │                 │   ClusterIP Services    │ │
                       │                 └─────────────────────────┘ │
                       └─────────────────────────────────────────────┘
```

### 🔧 Componenti dell'Architettura

#### 1. **Kubernetes Cluster (k3s)**
- **Namespace**: `crm-system`
- **Servizi**: ClusterIP (interni al cluster)
- **Pod**: PostgreSQL, Backend (Node.js), Frontend (React)
- **Storage**: PersistentVolume per database

#### 2. **Port-Forward Strutturale**
- **Meccanismo**: kubectl port-forward con --address=0.0.0.0
- **Porte**: 30002 (Frontend), 30003 (Backend API)
- **Binding**: Su tutte le interfacce per accesso esterno
- **Processo**: Background o servizio systemd

#### 3. **Rete e Firewall**
- **UFW**: Apertura automatica porte 30002/30003
- **Interfaccia**: ens33 (192.168.1.29)
- **Accesso**: Host Windows → DEV_VM → Cluster k8s

---

## 🚀 SCRIPTS PRINCIPALI

### 📁 Struttura Script
```
scripts/
├── deploy-k8s.sh                    # ✅ Gestione cluster Kubernetes
├── debug.sh                         # ✅ Troubleshooting e logs
├── portforward-original-ports.sh     # ✅ Accesso esterno porte 30002/30003
└── old/                             # 📁 Script obsoleti
    ├── egress-gateway-*.sh          # ❌ Tentativi egress gateway
    ├── fix-nodeport-*.sh            # ❌ Fix NodePort falliti
    ├── host-vm-network-debug.sh     # ❌ Debug network (ora integrato)
    └── nodeport-safe.sh             # ❌ Fix NodePort alternativi
```

### 🎯 Funzioni Script Attivi

#### **deploy-k8s.sh** - Gestione Cluster
- `start`: Deploy completo applicazione CRM
- `stop`: Fermata cluster mantenendo dati
- `restart`: Riavvio rolling dei pod
- `status`: Stato completo cluster e risorse
- `logs [component]`: Logs PostgreSQL/Backend/Frontend
- `scale [replicas]`: Scaling orizzontale
- `build`: Solo build immagini Docker
- `apply`: Solo applicazione manifest k8s

#### **portforward-original-ports.sh** - Accesso Esterno  
- `manual`: Port-forward processo background (default)
- `systemd`: Port-forward come servizio permanente
- `verify`: Test connettività e stato
- `status`: Status completo port-forward
- `restart`: Riavvio port-forward
- `cleanup`: Rimozione completa port-forward

#### **debug.sh** - Troubleshooting
- `status`: Stato completo sistema
- `logs [component]`: Logs dettagliati
- `fix`: Auto-fix problemi comuni
- `test`: Test connettività servizi

---

## 📋 COMANDI USO QUOTIDIANO

### 🚀 **Avvio Completo Sistema**
```bash
# 1. Deploy infrastruttura Kubernetes
cd ~/Claude/devops-pipeline-fase-6
./deploy-k8s.sh start

# 2. Setup accesso esterno (porte originali)
./scripts/portforward-original-ports.sh manual

# 3. Verifica accesso
curl -I http://192.168.1.29:30002        # Frontend
curl -I http://192.168.1.29:30003/api    # Backend API
```

### 📊 **Monitoraggio Sistema**
```bash
# Status cluster Kubernetes
./deploy-k8s.sh status

# Status port-forward
./scripts/portforward-original-ports.sh status

# Debug completo sistema
./scripts/debug.sh status

# Logs in tempo reale
./deploy-k8s.sh logs backend    # Backend logs
./deploy-k8s.sh logs frontend   # Frontend logs
./deploy-k8s.sh logs postgres   # Database logs
```

### 🔧 **Operazioni Manutenzione**

#### Riavvio Servizi
```bash
# Riavvio cluster (rolling restart)
./deploy-k8s.sh restart

# Riavvio solo port-forward
./scripts/portforward-original-ports.sh restart

# Riavvio componente specifico
kubectl rollout restart deployment/backend -n crm-system
```

#### Scaling Applicazione
```bash
# Scale a 3 repliche
./deploy-k8s.sh scale 3

# Scale manuale
kubectl scale deployment backend --replicas=3 -n crm-system
kubectl scale deployment frontend --replicas=2 -n crm-system
```

#### Troubleshooting
```bash
# Debug automatico problemi
./scripts/debug.sh fix

# Verifica connettività
./scripts/debug.sh test

# Port-forward su porte alternative (se 30002/30003 occupate)
kubectl port-forward -n crm-system svc/frontend-service 8080:80 &
kubectl port-forward -n crm-system svc/backend-service 8081:4001 &
```

### 🛑 **Fermata Sistema**
```bash
# 1. Stop port-forward (mantieni cluster)
./scripts/portforward-original-ports.sh cleanup

# 2. Stop cluster (mantieni dati)
./deploy-k8s.sh stop

# 3. Stop completo con rimozione dati
kubectl delete namespace crm-system
```

---

## 🔐 ACCESSO APPLICAZIONE

### 🌐 **URL di Accesso**
- **Frontend**: http://192.168.1.29:30002
- **Backend API**: http://192.168.1.29:30003/api
- **Health Check**: http://192.168.1.29:30003/api/health

### 🔑 **Credenziali Default**
- **Email**: admin@crm.local
- **Password**: admin123

### 🧪 **Test API Backend**
```bash
# Health check
curl http://192.168.1.29:30003/api/health

# Login
curl -X POST http://192.168.1.29:30003/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@crm.local","password":"admin123"}'

# Lista utenti (con token)
curl http://192.168.1.29:30003/api/users \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## ⚡ TROUBLESHOOTING COMUNE

### 🚨 **Port-Forward Non Funziona**
```bash
# Verifica processi port-forward
ps aux | grep "kubectl port-forward"

# Cleanup e riavvio
./scripts/portforward-original-ports.sh cleanup
./scripts/portforward-original-ports.sh manual

# Verifica porte in ascolto
sudo netstat -tulpn | grep -E ":30002|:30003"
```

### 🚨 **Pod Non Avviano**
```bash
# Verifica stato pod
kubectl get pods -n crm-system

# Logs pod problematico
kubectl logs -f deployment/backend -n crm-system

# Describe per eventi
kubectl describe pod <pod-name> -n crm-system

# Fix automatico
./scripts/debug.sh fix
```

### 🚨 **Database Connection Error**
```bash
# Verifica PostgreSQL
./deploy-k8s.sh logs postgres

# Restart database
kubectl rollout restart deployment/postgres -n crm-system

# Verifica PVC
kubectl get pvc -n crm-system
```

### 🚨 **Accesso da Host Windows Fallisce**
```bash
# Verifica firewall DEV_VM
sudo ufw status | grep -E "30002|30003"

# Test connettività locale
curl -I http://localhost:30002        # Da DEV_VM
curl -I http://192.168.1.29:30002     # Da DEV_VM IP

# Verifica port-forward binding
sudo netstat -tulpn | grep -E ":30002|:30003"
```

---

## 📈 PRESTAZIONI E SCALING

### 🔍 **Monitoraggio Risorse**
```bash
# Uso risorse pod
kubectl top pods -n crm-system

# Uso risorse nodi
kubectl top nodes

# Eventi cluster
kubectl get events -n crm-system --sort-by='.lastTimestamp'
```

### 📊 **Scaling Automatico**
Il sistema include HorizontalPodAutoscaler per scaling automatico basato su CPU:
- **Backend**: 2-5 repliche (target 70% CPU)
- **Frontend**: 2-3 repliche (target 60% CPU)

### 🔧 **Tuning Prestazioni**
```bash
# Aumento risorse backend
kubectl patch deployment backend -n crm-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","resources":{"requests":{"memory":"512Mi","cpu":"200m"},"limits":{"memory":"1Gi","cpu":"500m"}}}]}}}}'

# Verifica scaling automatico
kubectl get hpa -n crm-system
```

---

## 🔒 SICUREZZA

### 🛡️ **Configurazioni Sicurezza**
- **Secrets**: Credenziali database in k8s secrets
- **RBAC**: Accesso limitato tramite service accounts
- **Network Policies**: Isolamento traffico interno
- **Resource Limits**: Prevenzione resource exhaustion

### 🚫 **Firewall Rules**
```bash
# Verifica regole UFW attive
sudo ufw status numbered

# Solo porte necessarie aperte:
# - 22 (SSH)
# - 30002 (Frontend port-forward)  
# - 30003 (Backend port-forward)
# - 8080 (Jenkins - separato)
```

---

## 📝 BACKUP E RECOVERY

### 💾 **Backup Database**
```bash
# Backup PostgreSQL
kubectl exec -n crm-system deployment/postgres -- pg_dump -U crm_user crm_db > backup.sql

# Restore
kubectl exec -i -n crm-system deployment/postgres -- psql -U crm_user crm_db < backup.sql
```

### 📦 **Backup Configurazioni**
```bash
# Export tutti i manifest
kubectl get all -n crm-system -o yaml > crm-backup.yaml

# Export secrets
kubectl get secrets -n crm-system -o yaml > secrets-backup.yaml
```

---

## 🎯 DEPLOYMENT NOTES

### ✅ **Soluzione Finale**
- **Problema**: NodePort k3s non accessibili da host Windows
- **Root Cause**: iptables NAT k3s non funziona per traffico host→VM
- **Soluzione**: Port-forward strutturale su porte originali 30002/30003
- **Vantaggi**: Zero modifiche infrastruttura, accesso diretto, gestione semplice

### 🔄 **Processo Deployment**
1. **k3s cluster**: Servizi ClusterIP interni
2. **Port-forward**: Bridge verso esterno su porte concordate  
3. **Firewall**: Apertura automatica porte necessarie
4. **Monitoring**: Scripts debug e status integrati

### 🎉 **Risultato**
- **Frontend**: http://192.168.1.29:30002 ✅
- **Backend API**: http://192.168.1.29:30003/api ✅ 
- **Accesso Host Windows**: Funzionante ✅
- **Porte Originali**: Rispettate ✅
