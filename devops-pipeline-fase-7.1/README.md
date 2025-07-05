# FASE 7.1 - Setup Docker e SSH con Late-Commands

## 📋 Descrizione
Estensione incrementale della FASE 7 che aggiunge:
- Installazione Docker via late-commands
- Setup SSH keys automatico nell'autoinstall
- Configurazione Docker Registry su FE_VM
- Zero manual intervention post-deployment

## 🚀 Prerequisiti
- FASE 7 testata e funzionante
- Ubuntu 22.04 Server ISO disponibile
- VMware Workstation installato

## 📁 Struttura
```
devops-pipeline-fase-7.1/
├── terraform/
│   ├── main.tf                        # Terraform config con SSH key generation
│   └── templates/
│       ├── create-autoinstall-iso.sh.tpl  # ISO con late-commands estesi
│       └── create-vm-autoinstall.sh.tpl   # VM creation script
└── README.md                          # Questo file
```

## 🔧 Esecuzione

### Da DEV_VM:
```bash
cd ~/CRM-Fase7/devops-pipeline-fase-7.1/terraform

# Inizializza Terraform
terraform init

# Verifica piano
terraform plan

# Crea VM con Docker e SSH preconfigurati
terraform apply -auto-approve
```

### Tempo stimato: ~25-30 minuti

## ✅ Late-Commands Aggiunti (FASE 7.1)

### Docker Installation:
```yaml
# Repository Docker
- Aggiunge GPG key Docker
- Configura APT repository
- Installa docker-ce, docker-ce-cli, containerd.io
- Abilita servizio Docker

# Docker User Setup (post-boot):
- Servizio systemd per aggiungere user al gruppo docker
- Evita l'errore "group docker not found"
```

### SSH Keys:
```yaml
# SSH setup automatico
- Crea directory .ssh con permessi corretti
- Aggiunge chiave pubblica da DEV_VM
- Permette accesso senza password
```

### Registry Configuration:
```yaml
# Docker daemon.json
- Configura registry insecure 192.168.1.101:5000
- Prepara directory per registry (su master)
```

## 🔍 Differenze dalla FASE 7

| Aspetto | FASE 7 | FASE 7.1 |
|---------|--------|----------|
| Late-commands | 2 (sudoers only) | 15+ (Docker, SSH, Registry) |
| Docker | Manuale post-install | Automatico via late-commands |
| SSH Keys | Password only | Keys + Password |
| Registry | Setup manuale | Pre-configurato |

## 📊 Verifica Post-Deployment

### Test SSH senza password:
```bash
# Da DEV_VM (dopo ~25 minuti)
ssh devops@192.168.1.101  # No password richiesta!
ssh devops@192.168.1.102
ssh devops@192.168.1.103
```

### Test Docker:
```bash
# Su ogni VM
docker ps  # Funziona senza sudo dopo re-login
docker pull hello-world
```

### Test Registry (su FE_VM):
```bash
# Avvia registry
docker run -d -p 5000:5000 --name registry registry:2

# Test push
docker tag hello-world 192.168.1.101:5000/test
docker push 192.168.1.101:5000/test
```

## ⚠️ Note Importanti

### Gruppo Docker:
- Il gruppo viene creato da un servizio systemd al primo boot
- Richiede logout/login per essere attivo
- Alternativa: `sg docker -c 'docker ps'`

### SSH Keys:
- Generate automaticamente da Terraform su DEV_VM
- Copiate nelle VM durante autoinstall
- Backup in ~/.ssh/id_rsa

### Registry:
- daemon.json pre-configurato per registry insecure
- Registry container da avviare manualmente su FE_VM

## 🎯 Vantaggi FASE 7.1
1. **Zero Touch completo** - Nessun intervento post-install
2. **SSH automatico** - No più password per automazione
3. **Docker ready** - Subito pronto per build/deploy
4. **Registry ready** - Configurazione già presente

## ✅ Completamento
Quando tutte le VM sono accessibili via SSH senza password e Docker funziona, sei pronto per:
- **FASE 7.2**: Installazione K3s cluster
