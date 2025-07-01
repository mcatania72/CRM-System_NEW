#!/bin/bash

# =============================================================================
# AWS SETUP HELPER - Prepara DEV_VM per SSH deploy su AWS
# =============================================================================

set -e

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
log_info "🔧 AWS SETUP HELPER - Preparazione DEV_VM"
echo ""

# =============================================================================
# 1. VERIFICA PREREQUISITES
# =============================================================================
log_info "1. Verifica prerequisites DEV_VM..."

# Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js: $NODE_VERSION"
else
    log_warning "Node.js non installato"
    read -p "Installare Node.js 18? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        log_success "Node.js installato"
    fi
fi

# SSH
if command -v ssh &> /dev/null; then
    log_success "SSH client: OK"
else
    log_warning "SSH client non trovato"
    sudo apt update && sudo apt install -y openssh-client
    log_success "SSH client installato"
fi

# =============================================================================
# 2. SETUP SSH DIRECTORY
# =============================================================================
log_info "2. Setup SSH directory..."

SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
log_success "SSH directory: $SSH_DIR"

# =============================================================================
# 3. AWS KEYPAIR SETUP
# =============================================================================
log_info "3. AWS Keypair setup..."

echo ""
echo "📋 ISTRUZIONI AWS KEYPAIR:"
echo ""
echo "1. Vai su AWS Console → EC2 → Key Pairs"
echo "2. Crea/scarica keypair (formato .pem)"
echo "3. Sposta il file nella directory ~/.ssh/"
echo ""

read -p "Hai già scaricato la keypair AWS? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Inserisci il nome del file keypair (es: crm-aws-key.pem): " KEYNAME
    
    KEYPATH="$SSH_DIR/$KEYNAME"
    
    if [ -f "$KEYPATH" ]; then
        chmod 600 "$KEYPATH"
        log_success "Keypair configurata: $KEYPATH"
    else
        log_warning "File non trovato: $KEYPATH"
        echo ""
        echo "Sposta manualmente il file con:"
        echo "mv ~/Downloads/$KEYNAME $SSH_DIR/"
        echo "chmod 600 $SSH_DIR/$KEYNAME"
    fi
else
    echo ""
    echo "📥 DOWNLOAD KEYPAIR:"
    echo ""
    echo "1. Vai su: https://console.aws.amazon.com/ec2/v2/home#KeyPairs"
    echo "2. Clicca 'Create key pair'"
    echo "3. Nome: crm-aws-keypair"
    echo "4. Tipo: RSA, formato .pem"
    echo "5. Download e sposta in ~/.ssh/"
    echo ""
fi

# =============================================================================
# 4. EC2 INSTANCE INFO
# =============================================================================
log_info "4. Informazioni istanza EC2..."

echo ""
echo "📋 INFO ISTANZA EC2 NECESSARIE:"
echo ""
echo "• IP Pubblico (Public IPv4 address)"
echo "• Security Group con porte 22, 30002, 30003 aperte"
echo "• Istanza running"
echo ""

read -p "Hai già creato l'istanza EC2? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "🚀 CREA ISTANZA EC2:"
    echo ""
    echo "1. Vai su: https://console.aws.amazon.com/ec2/v2/home#Instances"
    echo "2. Clicca 'Launch Instance'"
    echo "3. Nome: CRM-Server"
    echo "4. AMI: Ubuntu Server 22.04 LTS"
    echo "5. Tipo: t2.micro (Free Tier)"
    echo "6. Keypair: crm-aws-keypair"
    echo "7. Security Group: Porte 22, 30002, 30003 da 0.0.0.0/0"
    echo "8. Storage: 30GB gp3"
    echo "9. Launch Instance"
    echo ""
fi

# =============================================================================
# 5. TEST CONNESSIONE (OPZIONALE)
# =============================================================================
log_info "5. Test connessione (opzionale)..."

read -p "Vuoi testare la connessione SSH ora? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Inserisci IP pubblico EC2: " AWS_IP
    read -p "Inserisci nome file keypair (es: crm-aws-key.pem): " KEY_FILE
    
    KEYPATH="$SSH_DIR/$KEY_FILE"
    
    if [ -f "$KEYPATH" ]; then
        log_info "Testing SSH connection..."
        if ssh -i "$KEYPATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$AWS_IP "echo 'SSH OK'"; then
            log_success "✅ Connessione SSH riuscita!"
        else
            log_warning "❌ Connessione SSH fallita"
            echo ""
            echo "🔧 TROUBLESHOOTING:"
            echo "• Verifica IP pubblico EC2"
            echo "• Verifica Security Group (porta 22 aperta)"
            echo "• Verifica istanza running"
            echo "• Verifica keypair corretta"
        fi
    else
        log_warning "Keypair non trovata: $KEYPATH"
    fi
fi

# =============================================================================
# 6. SUMMARY E NEXT STEPS
# =============================================================================
echo ""
log_success "🎉 SETUP COMPLETATO!"
echo ""
echo -e "${GREEN}📋 SUMMARY:${NC}"
echo "✅ SSH client configurato"
echo "✅ Directory ~/.ssh creata"
echo "✅ Istruzioni AWS keypair fornite"
echo "✅ Istruzioni EC2 instance fornite"
echo ""
echo -e "${BLUE}🚀 NEXT STEPS:${NC}"
echo ""
echo "1. Completa setup AWS keypair se non fatto"
echo "2. Crea/verifica istanza EC2 running"
echo "3. Esegui lo script principale:"
echo ""
echo "   cd devops-pipeline-fase-6/AWS/build-and-deploy"
echo "   ./local-build-ssh-deploy.sh"
echo ""
echo -e "${GREEN}🎯 READY PER DEPLOY!${NC}"
echo ""
