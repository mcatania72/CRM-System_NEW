# ☸️ FASE 6: Kubernetes Deployment

**Strategia DevSecOps Graduale - Week 6**

## 🎯 Obiettivo
Deploy del sistema CRM su cluster Kubernetes con orchestrazione completa, auto-scaling e preparazione per cloud AWS.

## 📊 Architettura K8s

```
┌─────────────────────────────────────────────────────────┐
│                  FASE 6: Kubernetes                    │
├─────────────────────────────────────────────────────────┤
│  ☸️  k3s Cluster (devvm - Ready)                        │
│  ├── 🗃️  PostgreSQL (postgres:16-alpine)               │
│  │   ├── PVC: 10Gi (local-path storage)                │
│  │   └── Resources: 512Mi-2Gi RAM, 200m-1000m CPU     │
│  ├── 🔧 Backend (2 replicas)                           │
│  │   ├── Image: crm-backend:latest                     │
│  │   └── Resources: 256Mi-512Mi RAM, 100m-500m CPU    │
│  ├── 🎨 Frontend (2 replicas)                          │
│  │   ├── Image: crm-frontend:latest                    │
│  │   └── Resources: 128Mi-256Mi RAM, 50m-200m CPU     │
│  └── 🌐 Traefik LoadBalancer (192.168.1.29)           │
│      ├── Frontend: http://192.168.1.29/crm            │
│      └── Backend: http://192.168.1.29/api             │
└─────────────────────────────────────────────────────────┘
```

## ✅ Caratteristiche FASE 6

### 🚀 Kubernetes Native
- ✅ **Namespace isolation**: `crm-system` dedicato
- ✅ **Dynamic storage**: local-path provisioner
- ✅ **Service discovery**: Internal DNS resolution
- ✅ **Load balancing**: Traefik ingress controller
- ✅ **High availability**: Multiple replicas
- ✅ **Auto-restart**: Self-healing containers

### 🔒 Security & Configuration
- ✅ **Secrets management**: K8s secrets per DB e JWT
- ✅ **ConfigMaps**: Environment-specific configuration
- ✅ **Network policies**: Pod-to-pod communication
- ✅ **Resource limits**: CPU/Memory constraints
- ✅ **Health checks**: Liveness/Readiness probes

### 📈 Scalability & Performance
- ✅ **Horizontal scaling**: HPA configurato
- ✅ **Resource optimization**: Request/limits appropriati
- ✅ **Storage persistence**: PostgreSQL data retention
- ✅ **Port management**: No conflicts (30002/30003)

## 🚀 Quick Start

### 1. Setup FASE 6
```bash
# Vai nella home directory
cd ~/Claude

# Sincronizza codice da GitHub (quando pronto)
git pull origin main

# Vai nella directory FASE 6
cd devops-pipeline-fase-6
```

### 2. Verifica Prerequisites
```bash
# Verifica k3s e setup environment
./prerequisites-k8s.sh
```

### 3. Deploy su Kubernetes
```bash
# Deploy completo CRM su K8s
./deploy-k8s.sh start

# Verifica stato deployment
./deploy-k8s.sh status
```

### 4. Test Suite Completa
```bash
# Test completi K8s + riutilizzo test precedenti
./test-k8s.sh

# Test specifici
./test-k8s.sh pods      # Solo pod status
./test-k8s.sh services  # Solo services
./test-k8s.sh ingress   # Solo ingress
./test-k8s.sh e2e       # End-to-end complete
```

## 🎯 Comandi Disponibili

### Prerequisites
- `./prerequisites-k8s.sh` - Verifica k3s e setup environment
- `./prerequisites-k8s.sh --fix` - Fix automatico problemi comuni

### Deploy Management
- `./deploy-k8s.sh start` - Deploy completo CRM su K8s
- `./deploy-k8s.sh stop` - Stop tutti i pods
- `./deploy-k8s.sh restart` - Restart deployment
- `./deploy-k8s.sh status` - Stato completo deployment
- `./deploy-k8s.sh logs` - Logs di tutti i pods
- `./deploy-k8s.sh scale <replicas>` - Scala backend/frontend

### Testing
- `./test-k8s.sh` - Test suite completa
- `./test-k8s.sh quick` - Test rapidi essenziali
- `./test-k8s.sh load` - Load testing
- `./test-k8s.sh debug` - Debug dettagliato

### Utilities
- `./scripts/cleanup-k8s.sh` - Cleanup completo namespace
- `./scripts/debug-k8s.sh` - Diagnostica avanzata
- `./scripts/scale-deployment.sh` - Scaling utilities

## 🌐 Accesso all'Applicazione

Una volta deployato:

### 🎨 Frontend Access
- **LoadBalancer**: http://192.168.1.29/crm
- **NodePort**: http://192.168.1.29:30002
- **Port Forward**: `kubectl port-forward -n crm-system svc/frontend-service 3000:80`

### 🔌 Backend API
- **LoadBalancer**: http://192.168.1.29/api
- **NodePort**: http://192.168.1.29:30003
- **Port Forward**: `kubectl port-forward -n crm-system svc/backend-service 3001:3001`

### 🔧 Kubernetes Dashboard
- **Traefik**: http://192.168.1.29:8080 (se abilitato)
- **kubectl**: `kubectl get all -n crm-system`

## 📊 Resource Allocation

### 💾 Storage
- **PostgreSQL PVC**: 10Gi (local-path)
- **Backup storage**: 5Gi (planning FASE 6.5)

### 🧠 Memory (Total: 23.7GB available)
- **PostgreSQL**: 512Mi request, 2Gi limit
- **Backend (2x)**: 256Mi request, 512Mi limit each
- **Frontend (2x)**: 128Mi request, 256Mi limit each
- **K8s overhead**: ~1Gi
- **Free buffer**: ~18Gi remaining

### ⚡ CPU (Total: 4 cores)
- **PostgreSQL**: 200m request, 1000m limit (25% max)
- **Backend (2x)**: 100m request, 500m limit each
- **Frontend (2x)**: 50m request, 200m limit each
- **K8s overhead**: ~500m
- **Free buffer**: ~1.5 cores remaining

## 🔄 Integrazione con Fasi Precedenti

### ✅ FASE 1-5 Compatibility
- **Container images**: Riutilizzo da FASE 2
- **Database schema**: Stesso PostgreSQL da FASE 2
- **Application code**: Zero modifiche necessarie
- **Test suites**: Estensione test esistenti
- **Jenkins CI/CD**: Pipeline estesa per K8s deploy

### 🔗 Build Process Integration
```bash
# Le immagini Docker vengono costruite dalle fasi precedenti
# e utilizzate direttamente nei manifests K8s:
# - crm-backend:latest (da FASE 2)
# - crm-frontend:latest (da FASE 2)
```

## 📈 Metriche di Successo

### 🎯 Criteri Minimi (80%+)
- ✅ Tutti i pods Running (3/3)
- ✅ Services esposti correttamente
- ✅ Database persistent e accessibile
- ✅ Frontend carica via LoadBalancer
- ✅ Backend API risponde
- ✅ Health checks passano

### 🏆 Criteri Ottimali (95%+)
- ✅ Load balancing funzionale
- ✅ Auto-scaling configurato
- ✅ Zero-downtime deployments
- ✅ Performance ≤ 200ms response time
- ✅ Resource utilization < 50%
- ✅ Ingress routing corretto

## 🔍 Troubleshooting

### Pod Issues
```bash
# Verifica stato pods
kubectl get pods -n crm-system

# Logs di un pod specifico
kubectl logs -n crm-system deployment/postgres

# Debug pod problematico
kubectl describe pod -n crm-system <pod-name>
```

### Service Issues
```bash
# Verifica services
kubectl get svc -n crm-system

# Test connettività interna
kubectl exec -n crm-system deployment/backend -- curl postgres-service:5432
```

### Storage Issues
```bash
# Verifica PVC
kubectl get pvc -n crm-system

# Descrizione storage
kubectl describe pv
```

### Network Issues
```bash
# Verifica ingress
kubectl get ingress -n crm-system

# Test LoadBalancer
curl http://192.168.1.29/crm
```

## 🎯 Prossimi Passi

Dopo completamento FASE 6:

### 📦 FASE 6.5: Backup & Operations
- PostgreSQL backup automation
- Monitoring e alerting
- Log aggregation
- Disaster recovery procedures

### 🌩️ FASE 7: AWS Cloud Migration
- AWS EC2 t2.micro deployment
- EKS preparation
- RDS PostgreSQL option
- CI/CD cloud integration

### 🏗️ FASE 8: Infrastructure as Code
- Terraform per AWS infrastructure
- Helm charts per K8s deployments
- GitOps con ArgoCD
- Multi-environment management

## 📞 Support

Per troubleshooting FASE 6:
1. Esegui `./test-k8s.sh debug`
2. Controlla logs: `./deploy-k8s.sh logs`
3. Verifica risorse: `kubectl get all -n crm-system`
4. Cleanup e restart: `./scripts/cleanup-k8s.sh && ./deploy-k8s.sh start`

---

**🏆 FASE 6 = Production-Ready Kubernetes Deployment**

*Enterprise-grade container orchestration per il sistema CRM*
