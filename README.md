# 🚀 CRM System - Enterprise DevSecOps Pipeline

[![Pipeline Status](https://img.shields.io/badge/Pipeline-FASE%203%20Complete-success)](https://github.com/mcatania72/CRM-System)
[![Build Status](https://img.shields.io/badge/Build-SUCCESS-brightgreen)](http://localhost:8080)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](./devops-pipeline-fase-2/)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-orange)](./devops-pipeline-fase-3/)

## 📋 Overview

Sistema CRM completo con **pipeline DevSecOps enterprise-grade** implementata attraverso 3 fasi graduali. Il progetto dimostra best practices moderne per sviluppo, containerizzazione e CI/CD automation.

### 🎯 Caratteristiche Principali

- 🖥️ **Full-Stack Application**: React + TypeScript frontend, Node.js + Express backend
- 🐳 **Container Ready**: Docker multi-stage builds ottimizzati
- 🔄 **CI/CD Pipeline**: Jenkins automation completa
- 🧪 **Test Coverage**: 100+ test automatici distribuiti su 3 fasi
- 🔒 **Security**: JWT auth, CORS, rate limiting, container security
- 📊 **Monitoring**: Health checks, smoke tests, logging strutturato

## 🏗️ Tech Stack

### Frontend
- **React 18** + **TypeScript** + **Material-UI v5**
- **Vite** build tool + **React Router**
- **React Hook Form** + **Yup** validation

### Backend
- **Node.js** + **Express** + **TypeScript**
- **SQLite** + **TypeORM** ORM
- **JWT** authentication + **bcryptjs**

### DevOps
- **Docker** + **Docker Compose**
- **Jenkins** CI/CD + **GitHub** integration
- **Multi-stage builds** + **Health checks**

## 🚀 Quick Start

### 📦 Opzione 1: Applicazione Nativa (FASE 1)

```bash
git clone https://github.com/mcatania72/CRM-System.git
cd CRM-System/devops-pipeline-fase-1

./prerequisites.sh    # Installa Node.js, npm, Git
./deploy.sh start     # Avvia applicazione
./test.sh            # Test completi (30+ test)
```

### 🐳 Opzione 2: Container Docker (FASE 2)

```bash
cd devops-pipeline-fase-2

./prerequisites-docker.sh     # Setup Docker environment
./deploy-containers.sh start  # Avvia container stack
./test-containers.sh         # Test container (31+ test)
```

### 🔄 Opzione 3: Pipeline CI/CD (FASE 3)

```bash
cd devops-pipeline-fase-3

./prerequisites-jenkins.sh  # Setup Jenkins + Java
./deploy-jenkins.sh start   # Avvia Jenkins server
./test-jenkins.sh           # Test infrastructure (27+ test)

# Accedi a Jenkins: http://localhost:8080
# Triggera "CRM-Build-Pipeline" → Build Now
```

## 🌐 Accesso all'Applicazione

Una volta avviata una delle 3 opzioni:

- **🎨 Frontend**: http://localhost:3000
- **🔌 Backend API**: http://localhost:3001/api
- **🔧 Jenkins**: http://localhost:8080 *(solo FASE 3)*

### 🔑 Credenziali Default

- **Login CRM**: `admin@crm.local` / `admin123`
- **Jenkins**: Password in `/var/lib/jenkins/secrets/initialAdminPassword`

## 📁 Struttura del Repository

```
CRM-System/
├── 📱 frontend/                 # React + TypeScript + Material-UI
├── 🔧 backend/                  # Node.js + Express + TypeORM
├── 🔥 devops-pipeline-fase-1/   # FASE 1: Validazione Base
├── 🐳 devops-pipeline-fase-2/   # FASE 2: Containerizzazione
├── 🔄 devops-pipeline-fase-3/   # FASE 3: CI/CD Jenkins
├── 📚 PIPELINE-DOCUMENTATION.md # Documentazione completa
└── 📖 README.md                # Questo file
```

## 📊 Pipeline DevSecOps - 3 Fasi

### 🔥 FASE 1: Validazione Base *(100% ✅)*
- ✅ Applicazione nativa Node.js + React
- ✅ Database SQLite con seed data
- ✅ Test automatici completi (30+ test)
- ✅ Deploy scripts automatizzati

### 🐳 FASE 2: Containerizzazione *(100% ✅)*
- ✅ Docker multi-stage builds
- ✅ Container orchestration con Docker Compose
- ✅ Network isolation + Volume persistence
- ✅ Health checks + Security best practices

### 🔄 FASE 3: CI/CD Jenkins *(100% ✅)*
- ✅ Pipeline automatizzata: Build → Test → Deploy
- ✅ Artifact management + Smoke tests
- ✅ GitHub integration + Auto deployment
- ✅ Zero-downtime deployment

## 🧪 Testing

Ogni fase include test automatici completi:

```bash
# 🔥 FASE 1 - Test Applicazione Nativa
cd devops-pipeline-fase-1 && ./test.sh
# Risultato atteso: 30+ test, 100% success

# 🐳 FASE 2 - Test Container + Integrazione FASE 1  
cd devops-pipeline-fase-2 && ./test-containers.sh
# Risultato atteso: 31+ test, 100% success

# 🔄 FASE 3 - Test CI/CD + Integrazione Completa
cd devops-pipeline-fase-3 && ./test-jenkins.sh
# Risultato atteso: 27+ test infrastructure, 100% success
```

## 🎯 Funzionalità CRM

### 👥 Gestione Clienti
- CRUD completo clienti
- Ricerca e filtri avanzati
- Gestione stati e categorie

### 💼 Opportunità di Vendita  
- Pipeline vendite completa
- Tracking stages e probabilità
- Reportistica vendite

### 📋 Attività e Task
- Task management integrato
- Priorità e scadenze
- Assegnazione team

### 💬 Interazioni Clienti
- Storico comunicazioni
- Note e follow-up
- Timeline attività

### 📊 Dashboard e Report
- Statistiche real-time
- Grafici e metriche KPI
- Export dati

## 🔒 Sicurezza

- **🔐 Autenticazione**: JWT tokens sicuri
- **🛡️ Authorization**: Role-based access control
- **🌐 CORS**: Configurazione restrittiva
- **⚡ Rate Limiting**: Protezione DDoS
- **🐳 Container Security**: Non-root users, multi-stage builds

## 📈 Performance

| Metrica | FASE 1 (Nativo) | FASE 2 (Container) | FASE 3 (Pipeline) |
|---------|------------------|-------------------|-------------------|
| **Startup Time** | ~30s | ~45s | ~5-8min* |
| **Memory Usage** | ~200MB | ~300MB | ~500MB |
| **Test Coverage** | 30+ tests | 31+ tests | 27+ infra tests |
| **Success Rate** | 100% | 100% | 100% |

*Pipeline include: build + test + deploy completo

## 📚 Documentazione Completa

📖 **[PIPELINE-DOCUMENTATION.md](./PIPELINE-DOCUMENTATION.md)** - Documentazione tecnica completa:
- Architettura dettagliata
- Guide setup e configurazione  
- Troubleshooting e FAQ
- Best practices DevOps
- Roadmap fasi future

## 🛠️ Troubleshooting

### ❗ Problemi Comuni

**Q: Applicazione non si avvia**
```bash
# Verifica prerequisiti
./prerequisites.sh              # FASE 1
./prerequisites-docker.sh       # FASE 2
./prerequisites-jenkins.sh      # FASE 3

# Controlla status
./deploy.sh status              # FASE 1
./deploy-containers.sh status   # FASE 2  
./deploy-jenkins.sh status      # FASE 3
```

**Q: Test falliscono**
```bash
# Reset completo
./deploy.sh restart             # FASE 1
./deploy-containers.sh restart  # FASE 2
./deploy-jenkins.sh restart     # FASE 3
```

**Q: Porte occupate**
```bash
# Verifica porte in uso
netstat -tlnp | grep -E "(3000|3001|8080)"

# Libera porte se necessario
sudo lsof -ti:3000 | xargs -r kill -9
sudo lsof -ti:3001 | xargs -r kill -9
```

### 📋 Log Locations

```bash
# FASE 1 - Applicazione Nativa
~/deploy.log, ~/backend.log, ~/frontend.log

# FASE 2 - Container
docker logs crm-backend
docker logs crm-frontend

# FASE 3 - Jenkins
/var/log/jenkins/jenkins.log
Jenkins GUI → Console Output
```

## 🚀 Roadmap Futuro

### 🎯 FASE 4: Security & Monitoring *(Pianificata)*
- SonarQube code quality
- OWASP security testing
- Prometheus + Grafana monitoring
- ELK stack logging

### 🎯 FASE 5: Kubernetes *(Pianificata)*
- K8s orchestration
- Helm charts
- Auto-scaling
- Service mesh

### 🎯 FASE 6: Infrastructure as Code *(Pianificata)*
- Terraform provisioning
- Multi-environment
- GitOps with ArgoCD
- Disaster recovery

## 🤝 Contributing

1. Fork del repository
2. Crea feature branch: `git checkout -b feature/amazing-feature`
3. Commit: `git commit -m 'Add amazing feature'`
4. Push: `git push origin feature/amazing-feature`
5. Apri Pull Request

## 📄 Licenza

Questo progetto è open source e disponibile sotto [MIT License](LICENSE).

## 🏆 Achievement Unlocked

✅ **DevOps Engineer Enterprise** - Pipeline completa implementata  
✅ **Container Specialist** - Docker multi-stage mastery  
✅ **CI/CD Architect** - Jenkins automation expert  
✅ **Full-Stack Developer** - React + Node.js application  

---

📧 **Contatto**: [GitHub Issues](https://github.com/mcatania72/CRM-System/issues)  
📖 **Docs**: [Pipeline Documentation](./PIPELINE-DOCUMENTATION.md)  
🚀 **Demo**: http://localhost:3000 *(dopo setup)*

*Progetto realizzato per dimostrare competenze DevSecOps enterprise-grade*