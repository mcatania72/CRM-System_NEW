# FASE 3: CI/CD Base con Jenkins

## 📋 Panoramica FASE 3
Implementazione completa di Continuous Integration e Continuous Deployment utilizzando Jenkins per il CRM System.

### ✅ Prerequisiti dalle Fasi Precedenti
- **FASE 1**: Applicazione nativa funzionante al 100%
- **FASE 2**: Containerizzazione completa con Docker

### 🎯 Obiettivi FASE 3
- **Jenkins Server**: Installazione e configurazione completa
- **Pipeline Automatizzate**: Build, test e deploy automatici
- **GitHub Integration**: Webhook per trigger automatici
- **Docker Integration**: Deploy container automatizzato
- **Artifact Management**: Gestione build e release
- **Monitoring**: Log e notifiche pipeline

## 🚀 Componenti FASE 3

### 📋 Script Principali
- **prerequisites-jenkins.sh**: Verifica e installazione automatica Jenkins + Java
- **deploy-jenkins.sh**: Gestione completa server Jenkins e pipeline
- **test-jenkins.sh**: Test pipeline + riutilizzo test FASE 1 e 2
- **sync-devops-config.sh**: Sincronizzazione repository

### 🔧 Configurazioni Jenkins
- **jenkins/**: Directory configurazioni Jenkins
  - **plugins.txt**: Lista plugin essenziali
  - **jobs/**: Definizioni job e pipeline
  - **docker-compose-jenkins.yml**: Jenkins containerizzato

### 📊 Pipeline Definite
1. **CRM-Build-Pipeline**: Build automatico su commit
2. **CRM-Test-Pipeline**: Test automatici (FASE 1 + 2)
3. **CRM-Deploy-Pipeline**: Deploy automatico container
4. **CRM-Release-Pipeline**: Gestione release e tag

## 🔄 Workflow CI/CD

### 1. Developer Workflow
```bash
git push origin main
↓
GitHub Webhook → Jenkins
↓
Automatic Build → Test → Deploy
```

### 2. Pipeline Flow
```
GitHub Push → Jenkins Trigger → Build Container → Run Tests → Deploy to DEV → Notify Status
```

### 3. Approval Workflow
- **DEV**: Deploy automatico
- **STAGING**: Deploy automatico con test completi
- **PROD**: Deploy manuale con approvazione

## 🛠️ Tecnologie Utilizzate

### Core CI/CD
- **Jenkins**: Server CI/CD principale
- **Blue Ocean**: UI moderna per pipeline
- **Docker**: Containerizzazione build e deploy
- **Git**: Version control e trigger

### Plugin Jenkins
- **GitHub Integration**: Webhook e status updates
- **Docker Plugin**: Build e push immagini
- **Pipeline Plugin**: Pipeline as Code
- **Blue Ocean**: UI avanzata
- **Slack/Email**: Notifiche

### Security & Quality
- **SonarQube**: Code quality analysis
- **OWASP Dependency Check**: Security scanning
- **Docker Security**: Container vulnerability scanning

## 📈 Metriche e Monitoring

### Build Metrics
- **Build Success Rate**: Target 95%+
- **Build Time**: Target <10 minuti
- **Test Coverage**: Mantenimento >90%
- **Deploy Frequency**: Tracking deploy automatici

### Quality Gates
- **Code Quality**: SonarQube quality gate
- **Security**: Zero critical vulnerabilities
- **Performance**: Response time <2s
- **Availability**: >99% uptime

## 🚀 Getting Started

### 1. Setup FASE 3
```bash
cd ~
mkdir -p devops-pipeline-fase-3
cd devops-pipeline-fase-3

# Scarica sync script
curl -o sync-devops-config.sh https://raw.githubusercontent.com/mcatania72/CRM-System/main/devops-pipeline-fase-3/sync-devops-config.sh
chmod +x sync-devops-config.sh

# Sincronizza tutto
./sync-devops-config.sh
```

### 2. Installa Prerequisites
```bash
# Verifica e installa Jenkins + Java
./prerequisites-jenkins.sh
```

### 3. Deploy Jenkins
```bash
# Avvia Jenkins server
./deploy-jenkins.sh start

# Configura pipeline
./deploy-jenkins.sh setup-pipelines
```

### 4. Test Pipeline
```bash
# Test completi CI/CD
./test-jenkins.sh

# Test manuali
./test-jenkins.sh manual
```

## 🎯 Criteri di Successo FASE 3

### ✅ Obiettivi Minimi (80%)
- Jenkins server funzionante
- Pipeline base operativa
- Integration con GitHub
- Build automatico funzionante

### 🏆 Obiettivi Ottimali (95%+)
- Pipeline complete (build, test, deploy)
- Webhook GitHub automatici
- Notifiche integrate
- Quality gates funzionanti
- Monitoring completo

### 🔥 Obiettivi Avanzati (100%)
- Multi-environment pipeline
- Approval workflow
- Automatic rollback
- Performance monitoring
- Security scanning integrato

## 📚 Documentazione

### Command Reference
```bash
# Jenkins Management
./deploy-jenkins.sh start|stop|restart|status|logs
./deploy-jenkins.sh setup-pipelines
./deploy-jenkins.sh backup|restore

# Pipeline Testing
./test-jenkins.sh                    # Test completi
./test-jenkins.sh pipeline-only     # Solo pipeline
./test-jenkins.sh integration       # Test integrazione

# Monitoring
./deploy-jenkins.sh logs jenkins    # Log Jenkins
./deploy-jenkins.sh logs pipeline   # Log pipeline
./deploy-jenkins.sh metrics         # Metriche performance
```

### Troubleshooting
- **Jenkins non si avvia**: Verifica Java, porte, permessi
- **Pipeline fallisce**: Controlla log, credenziali GitHub
- **Webhook non funziona**: Verifica URL, secret, firewall
- **Build lento**: Ottimizza Dockerfile, cache, risorse

## 🔗 Link Utili
- **Jenkins Dashboard**: http://localhost:8080
- **Blue Ocean**: http://localhost:8080/blue
- **GitHub Webhook**: http://DEV_VM_IP:8080/github-webhook/
- **Build History**: http://localhost:8080/job/CRM-Build-Pipeline/

---

## 🎉 Prossime Fasi
Una volta completata la FASE 3:
- **FASE 4**: Security e Monitoring Avanzato
- **FASE 5**: Kubernetes Orchestration
- **FASE 6**: Infrastructure as Code Completo