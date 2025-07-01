# DOCUMENTAZIONE FASE 7 - Infrastructure as Code

## 🎯 Overview Completo

La **FASE 7** implementa Infrastructure as Code usando **Terraform** per automatizzare la creazione di un cluster Kubernetes distribuito su 3 VM VMware, preparando la base per il deployment dell'applicazione CRM in modalità enterprise.

## 🏗️ Architettura Implementata

### **Infrastructure Layout**
```
┌─────────────────────────────────────────────────────────────┐
│                     DEV_VM (Host Ubuntu)                   │
│                   VMware Workstation Pro                   │
│  ┌─────────────────────────────────────────────────────────┤
│  │               Terraform-Managed VMs                     │
│  │                                                        │
│  │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  │  │   SPESE_FE_VM    │ │   SPESE_BE_VM    │ │   SPESE_DB_VM    │
│  │  │  192.168.1.101   │ │  192.168.1.102   │ │  192.168.1.103   │
│  │  │                  │ │                  │ │                  │
│  │  │ ☸️ K8s Master     │ │ ☸️ K8s Worker     │ │ ☸️ K8s Worker     │
│  │  │ 🌐 Frontend       │ │ ⚙️ Backend        │ │ 🗄️ Database       │
│  │  │ 🔄 Ingress Ctrl   │ │ 📡 API Gateway    │ │ 💾 Storage        │
│  │  │ 🎛️ Load Balancer  │ │ 🔧 App Services   │ │ 📋 Backup         │
│  │  │                  │ │                  │ │                  │
│  │  │ 4GB RAM, 2 CPU   │ │ 4GB RAM, 2 CPU   │ │ 4GB RAM, 2 CPU   │
│  │  │ 25GB SSD         │ │ 25GB SSD         │ │ 25GB SSD         │
│  │  └──────────────────┘ └──────────────────┘ └──────────────────┘
│  └─────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────┘
```

### **Kubernetes Cluster Configuration**
- **Cluster Name**: crm-production
- **Kubernetes Version**: 1.28+
- **Container Runtime**: containerd
- **CNI Plugin**: Flannel (pod-network-cidr: 10.244.0.0/16)
- **Load Balancer**: MetalLB (IP pool: 192.168.1.200-220)
- **Ingress Controller**: Nginx Ingress
- **Service Mesh**: Ready for Istio (future implementation)

## 📁 Struttura File Creata

```
devops-pipeline-fase-7/
├── 📋 README.md                          # Architettura e overview
├── 📋 DOCUMENTAZIONE_FASE_7.md          # Documentazione completa (questo file)
├── 🔄 sync-devops-config.sh             # Sincronizzazione repository
├── ✅ prerequisites.sh                   # Verifica e installazione dipendenze
├── 🚀 deploy_infrastructure.sh          # Deploy infrastruttura Terraform
├── 🧪 test_infrastructure.sh            # Test completo infrastruttura
├── 📦 deploy_application.sh             # Deploy applicazione (placeholder FASE 7.5)
├── 🔬 test_application.sh               # Test applicazione (placeholder FASE 7.5)
│
├── ☁️ terraform/
│   ├── 🔧 main.tf                       # Configurazione Terraform principale
│   ├── 📊 variables.tf                  # Definizione variabili
│   ├── 📝 terraform.tfvars             # Valori configurazione (auto-generato)
│   │
│   └── 📄 templates/
│       ├── 🖥️ create-vm.sh.tpl          # Template creazione VM VMware
│       ├── ☁️ cloud-init.yml.tpl        # Template configurazione cloud-init
│       ├── 🌐 network-config.yml.tpl    # Template configurazione rete
│       └── ☸️ setup-k8s.sh.tpl          # Template setup Kubernetes
│
└── 📊 logs/                             # Directory log (auto-creata)
    ├── infrastructure-deploy.log
    ├── infrastructure-test.log
    └── deployment-info.txt
```

## 🛠️ Componenti Tecnologici

### **Infrastructure as Code**
- **Terraform**: Gestione dichiarativa infrastruttura
- **VMware Workstation**: Virtualizzazione locale
- **Cloud-init**: Configurazione automatica VM
- **Bash Scripts**: Automazione e orchestrazione

### **Container Orchestration**
- **Kubernetes**: Container orchestration platform
- **kubeadm**: Cluster bootstrapping
- **kubectl**: Cluster management
- **Helm**: Package manager (ready for use)

### **Networking**
- **Flannel**: Pod networking (VXLAN)
- **MetalLB**: Load balancer per bare metal
- **Nginx Ingress**: HTTP/HTTPS routing
- **CoreDNS**: Service discovery

### **Storage**
- **Local Path Provisioner**: Dynamic storage provisioning
- **Persistent Volumes**: Stateful application support
- **Storage Classes**: Multiple storage tiers

## 🚀 Deployment Workflow

### **1. Prerequisites Check**
```bash
./prerequisites.sh
```
**Verifica e installa:**
- Docker Engine
- Terraform CLI
- VMware Workstation Pro
- kubectl & Helm
- System resources (16GB+ RAM, 4+ CPU cores, 100GB+ storage)

### **2. Infrastructure Deployment**
```bash
./deploy_infrastructure.sh
```
**Processo automatizzato:**
1. **Preparation**: Terraform configuration generation
2. **Planning**: Infrastructure plan validation
3. **VM Creation**: 3 VMware VMs with Ubuntu 22.04
4. **OS Configuration**: Cloud-init automated setup
5. **Kubernetes Bootstrap**: Master node initialization
6. **Worker Join**: Automatic cluster formation
7. **Networking Setup**: CNI and load balancer configuration
8. **Verification**: End-to-end connectivity testing

### **3. Infrastructure Testing**
```bash
./test_infrastructure.sh
```
**Test Suite Completa:**
- ✅ VM existence and resource allocation
- ✅ Network connectivity and SSH access
- ✅ Kubernetes cluster health
- ✅ Node roles and labels
- ✅ System pods functionality
- ✅ Container networking (Flannel)
- ✅ Load balancer (MetalLB)
- ✅ Ingress controller (Nginx)
- ✅ Storage provisioning
- ✅ Performance benchmarks
- ✅ Security compliance

## 📊 Resource Allocation

### **Total Infrastructure Resources**
- **Total RAM**: 12GB (4GB × 3 VMs)
- **Total CPU**: 6 cores (2 cores × 3 VMs)
- **Total Storage**: 75GB (25GB × 3 VMs)
- **Network**: Bridged 192.168.1.0/24

### **Per-VM Breakdown**
| VM | Role | IP | CPU | RAM | Storage | Services |
|---|---|---|---|---|---|---|
| SPESE_FE_VM | Master | 192.168.1.101 | 2 cores | 4GB | 25GB | K8s Master, Frontend, Ingress |
| SPESE_BE_VM | Worker | 192.168.1.102 | 2 cores | 4GB | 25GB | K8s Worker, Backend, API |
| SPESE_DB_VM | Worker | 192.168.1.103 | 2 cores | 4GB | 25GB | K8s Worker, Database, Storage |

### **Kubernetes Resource Distribution**
```yaml
# Optimized for distributed deployment
Frontend (SPESE_FE_VM):
  replicas: 2
  resources:
    requests: { memory: "256Mi", cpu: "100m" }
    limits: { memory: "512Mi", cpu: "500m" }

Backend (SPESE_BE_VM):
  replicas: 2  
  resources:
    requests: { memory: "512Mi", cpu: "200m" }
    limits: { memory: "1Gi", cpu: "1000m" }

Database (SPESE_DB_VM):
  replicas: 1
  resources:
    requests: { memory: "1Gi", cpu: "250m" }
    limits: { memory: "2Gi", cpu: "1000m" }
```

## 🔧 Configurazioni Avanzate

### **VM Specifications**
```yaml
vm_specs:
  memory_gb: 4                    # 4GB RAM per VM
  cpu_cores: 2                    # 2 CPU cores per VM
  disk_gb: 25                     # 25GB storage dinamico
  os: "Ubuntu 22.04 LTS Desktop"
  
vm_network:
  subnet: "192.168.1.0/24"
  gateway: "192.168.1.1"
  dns: ["8.8.8.8", "8.8.4.4"]
```

### **Kubernetes Cluster Config**
```yaml
cluster_config:
  pod_network_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/12"
  dns_domain: "cluster.local"
  
cni_plugin: "flannel"
load_balancer: "metallb"
ingress_controller: "nginx"
```

### **Security Configuration**
```yaml
security:
  rbac_enabled: true
  network_policies: supported
  pod_security_standards: enforced
  
firewall_rules:
  ssh: 22
  kubernetes_api: 6443
  etcd: 2379-2380
  kubelet: 10250
  nodeport_range: 30000-32767
  flannel_vxlan: 8472
```

## 🔍 Monitoraggio e Logging

### **Health Checks Implementati**
1. **VM Level**: Ping, SSH, resource utilization
2. **Kubernetes Level**: API server, node status, pod health
3. **Network Level**: Inter-pod communication, service discovery
4. **Storage Level**: PVC binding, volume mounting
5. **Application Level**: Ready for service health checks

### **Log Aggregation**
- **Infrastructure Logs**: `/devops-pipeline-fase-7/logs/`
- **VM System Logs**: `/var/log/` on each VM
- **Kubernetes Logs**: `kubectl logs` per component
- **Application Logs**: Ready for centralized logging (ELK stack)

## 🎯 Success Metrics

### **Infrastructure Deployment Success**
- ✅ All 3 VMs created and running
- ✅ All VMs accessible via SSH
- ✅ Kubernetes cluster formed (1 master + 2 workers)
- ✅ All system pods running
- ✅ CNI networking functional
- ✅ Load balancer operational
- ✅ Storage provisioning working

### **Performance Benchmarks**
- **VM Boot Time**: < 5 minutes per VM
- **Kubernetes Cluster Init**: < 10 minutes
- **Pod Scheduling Time**: < 30 seconds
- **Service Discovery**: < 5 seconds
- **Storage Provisioning**: < 60 seconds

### **Reliability Targets**
- **Cluster Uptime**: 99.9%
- **Pod Recovery Time**: < 2 minutes
- **Rolling Update Zero-Downtime**: ✅
- **Node Failure Tolerance**: 1 worker node

## 🚀 Deployment Commands

### **Quick Start Sequence**
```bash
# 1. Sync repository
./sync-devops-config.sh

# 2. Install prerequisites  
./prerequisites.sh

# 3. Deploy infrastructure
./deploy_infrastructure.sh

# 4. Test infrastructure
./test_infrastructure.sh

# 5. Access cluster
export KUBECONFIG=~/.kube/config-crm-cluster
kubectl get nodes
```

### **Advanced Operations**
```bash
# SSH to VMs
ssh devops@192.168.1.101  # Master node
ssh devops@192.168.1.102  # Backend worker
ssh devops@192.168.1.103  # Database worker

# Kubernetes management
kubectl get all --all-namespaces
kubectl top nodes
kubectl describe node <node-name>

# Terraform operations
cd terraform/
terraform plan
terraform apply
terraform destroy  # CAUTION: Destroys all VMs
```

## 🔄 Troubleshooting Guide

### **Common Issues and Solutions**

**1. VM Creation Failed**
```bash
# Check VMware Workstation
vmrun list
# Check ISO file path
ls -la /path/to/ubuntu.iso
# Check available disk space
df -h
```

**2. Kubernetes Cluster Issues**
```bash
# Check cluster status
kubectl cluster-info
# Check node status
kubectl get nodes -o wide
# Check system pods
kubectl get pods --all-namespaces
```

**3. Network Connectivity Issues**
```bash
# Test VM connectivity
ping 192.168.1.101
# Test SSH
ssh -v devops@192.168.1.101
# Check firewall rules
sudo ufw status
```

**4. Resource Constraints**
```bash
# Check system resources
free -h
nproc
df -h
# Check VM resources
vmrun getGuestIPAddress <vmx-file>
```

## 📈 Next Steps (FASE 7.5)

### **Application Deployment** 
- **CRM Frontend**: React application con Material-UI
- **CRM Backend**: Node.js + Express + TypeORM
- **Database**: PostgreSQL con persistent storage
- **Load Balancing**: MetalLB per distribuire traffic
- **Ingress Routing**: Nginx per HTTP/HTTPS access

### **Advanced Features**
- **Horizontal Pod Autoscaler**: Auto-scaling basato su CPU/memory
- **Vertical Pod Autoscaler**: Right-sizing automatico
- **Cluster Autoscaler**: Node scaling automatico
- **Service Mesh**: Istio per traffic management
- **Monitoring**: Prometheus + Grafana stack
- **Logging**: ELK stack centralizzato

### **Production Readiness**
- **Backup Strategy**: Database backup automatico
- **Disaster Recovery**: Multi-zone deployment simulation
- **Security Hardening**: Pod Security Standards, Network Policies
- **Compliance**: Security scanning e audit logs

## 🎉 Conclusioni

La **FASE 7** stabilisce una base solida di Infrastructure as Code per il progetto CRM, implementando:

✅ **Automazione Completa**: Terraform per gestione infrastruttura
✅ **Scalabilità**: Cluster Kubernetes distribuito e scalabile  
✅ **Resilienza**: Multi-node deployment con fault tolerance
✅ **Production-Ready**: Configurazioni enterprise-grade
✅ **Cloud-Ready**: Preparazione per migration AWS EKS

L'infrastruttura è ora pronta per ospitare l'applicazione CRM in modalità enterprise, con tutte le caratteristiche necessarie per un deployment production-ready.

---

**Infrastructure as Code completato con successo!** 🏗️🚀
