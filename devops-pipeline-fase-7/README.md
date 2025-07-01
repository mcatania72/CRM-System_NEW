# FASE 7: Infrastructure as Code (Terraform + VMware)

## 🎯 Obiettivo
Automatizzare la creazione di infrastruttura con **Terraform** per deploy applicazione CRM su cluster Kubernetes distribuito su 3 VM VMware.

## 🏗️ Architettura Target

### **Infrastructure Layout**
```
┌─────────────────────────────────────────────────────────────┐
│                     DEV_VM (Host)                          │
│                   Ubuntu + VMware                          │
│  ┌─────────────────────────────────────────────────────────┤
│  │               VMware Infrastructure                     │
│  │                                                        │
│  │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  │  │   SPESE_FE_VM    │ │   SPESE_BE_VM    │ │   SPESE_DB_VM    │
│  │  │  192.168.1.101   │ │  192.168.1.102   │ │  192.168.1.103   │
│  │  │                  │ │                  │ │                  │
│  │  │ K8s Master Node  │ │ K8s Worker Node  │ │ K8s Worker Node  │
│  │  │ + Frontend Pods  │ │ + Backend Pods   │ │ + Database Pods  │
│  │  │ + Ingress Ctrl   │ │ + App Services   │ │ + Storage        │
│  │  │                  │ │                  │ │ + Backup         │
│  │  │ 4GB RAM, 2 CPU   │ │ 4GB RAM, 2 CPU   │ │ 4GB RAM, 2 CPU   │
│  │  │ 25GB Disk        │ │ 25GB Disk        │ │ 25GB Disk        │
│  │  └──────────────────┘ └──────────────────┘ └──────────────────┘
│  └─────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────┘
```

### **Network Configuration**
- **Network Segment:** 192.168.1.0/24
- **Gateway:** 192.168.1.1
- **DNS:** 8.8.8.8, 8.8.4.4
- **Inter-VM Communication:** Full mesh connectivity

### **Kubernetes Cluster**
- **Cluster Name:** crm-production
- **CNI:** Flannel or Calico
- **Load Balancer:** MetalLB + Nginx Ingress
- **Storage:** Distributed storage across nodes

## 🛠️ Componenti

### **Infrastructure Scripts**
1. **sync-devops-config.sh** - Sincronizzazione repository
2. **prerequisites.sh** - Verifica e installazione dipendenze
3. **deploy_infrastructure.sh** - Creazione VM con Terraform
4. **test_infrastructure.sh** - Test infrastruttura deployata

### **Application Scripts** (Fase 7.5)
5. **deploy_application.sh** - Deploy CRM su cluster K8s
6. **test_application.sh** - Test applicazione deployata

## 📋 Resource Allocation

### **Per VM (Total: 12GB RAM, 6 CPU, 75GB Storage)**
```yaml
vm_specs:
  cpu: 2 cores
  memory: 4GB RAM
  disk: 25GB (dynamic allocation)
  os: Ubuntu 22.04 LTS
  network: Bridged (192.168.1.x)
```

### **Kubernetes Resource Distribution**
```yaml
# SPESE_FE_VM (Master + Frontend)
frontend:
  replicas: 2
  resources:
    requests: { memory: "256Mi", cpu: "100m" }
    limits: { memory: "512Mi", cpu: "500m" }

# SPESE_BE_VM (Worker + Backend)  
backend:
  replicas: 2
  resources:
    requests: { memory: "512Mi", cpu: "200m" }
    limits: { memory: "1Gi", cpu: "1000m" }

# SPESE_DB_VM (Worker + Database)
postgres:
  replicas: 1
  resources:
    requests: { memory: "1Gi", cpu: "250m" }
    limits: { memory: "2Gi", cpu: "1000m" }
```

## 🎯 Vantaggi Architettura

### **High Availability**
- ✅ Frontend accessible anche se backend down
- ✅ Database isolation e protezione
- ✅ Load balancing automatico

### **Scalabilità**
- ✅ Scale orizzontale per componente
- ✅ Resource allocation dedicated
- ✅ Easy upgrade individual nodes

### **Development Experience**
- ✅ Production-like environment
- ✅ Multi-node Kubernetes experience
- ✅ Network troubleshooting skills
- ✅ Distributed systems understanding

### **Cloud Readiness**
- ✅ Preparazione per AWS EKS
- ✅ Multi-AZ deployment simulation
- ✅ Container orchestration skills

## 🚀 Deployment Strategy

### **Phase 1: Infrastructure**
1. Terraform creates 3 VMs
2. Bootstrap Kubernetes cluster
3. Configure networking and storage
4. Validate infrastructure health

### **Phase 2: Application** 
1. Deploy CRM manifests across cluster
2. Configure load balancing and ingress
3. Setup monitoring and logging
4. Validate application functionality

## 🎉 Success Metrics

- ✅ **Infrastructure:** 3 VMs running with K8s cluster healthy
- ✅ **Application:** CRM accessible via load balancer
- ✅ **Performance:** Response time < 500ms
- ✅ **Resilience:** Survives single node failure
- ✅ **Monitoring:** Health checks and metrics functional

---

**Ready to implement Infrastructure as Code with Terraform!** 🏗️
