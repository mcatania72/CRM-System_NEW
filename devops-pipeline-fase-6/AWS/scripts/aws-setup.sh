#!/bin/bash

# ================================
# AWS EC2 SETUP - CRM SYSTEM
# Setup iniziale istanza EC2 t2.micro per deployment CRM
# ================================

set -euo pipefail

# Configurazione AWS
AWS_REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0c02fb55956c7d316"  # Ubuntu 22.04 LTS
KEY_NAME="crm-key-pair"
SECURITY_GROUP="crm-security-group"
INSTANCE_NAME="crm-system-instance"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== 🌩️ AWS EC2 SETUP - CRM SYSTEM ==="
echo "Region: $AWS_REGION"
echo "Instance Type: $INSTANCE_TYPE"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: VERIFICA PREREQUISITI
# ================================
check_prerequisites() {
    log_info "🔍 Verifica prerequisiti AWS..."
    
    # Verifica AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "❌ AWS CLI non installato"
        echo "Installa AWS CLI:"
        echo "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
        echo "unzip awscliv2.zip && sudo ./aws/install"
        exit 1
    fi
    
    # Verifica configurazione AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "❌ AWS non configurato"
        echo "Configura AWS CLI:"
        echo "aws configure"
        exit 1
    fi
    
    # Verifica jq
    if ! command -v jq &> /dev/null; then
        log_warning "⚠️ jq non installato - installazione..."
        sudo apt update && sudo apt install -y jq
    fi
    
    log_success "✅ Prerequisiti verificati"
}

# ================================
# FUNZIONE: CREA KEY PAIR
# ================================
create_key_pair() {
    log_info "🔑 Gestione key pair..."
    
    # Verifica se esiste già
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_warning "⚠️ Key pair $KEY_NAME già esistente"
        return 0
    fi
    
    # Crea nuovo key pair
    log_info "🔐 Creazione key pair $KEY_NAME..."
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    
    # Imposta permessi corretti
    chmod 600 "${KEY_NAME}.pem"
    
    log_success "✅ Key pair creato: ${KEY_NAME}.pem"
}

# ================================
# FUNZIONE: CREA SECURITY GROUP
# ================================
create_security_group() {
    log_info "🛡️ Gestione security group..."
    
    # Verifica se esiste già
    if aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" --region "$AWS_REGION" &> /dev/null; then
        log_warning "⚠️ Security group $SECURITY_GROUP già esistente"
        return 0
    fi
    
    # Crea security group
    log_info "🔒 Creazione security group $SECURITY_GROUP..."
    local sg_id=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP" \
        --description "CRM System Security Group" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    # Aggiungi regole inbound
    log_info "📝 Configurazione regole security group..."
    
    # SSH access
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # HTTP/HTTPS access
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # CRM Application ports
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 30002 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 30003 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    log_success "✅ Security group creato: $sg_id"
}

# ================================
# FUNZIONE: CREA ISTANZA EC2
# ================================
create_instance() {
    log_info "🖥️ Creazione istanza EC2..."
    
    # Verifica se esiste già un'istanza con lo stesso nome
    local existing_instance=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$existing_instance" != "None" ] && [ "$existing_instance" != "null" ]; then
        log_warning "⚠️ Istanza $INSTANCE_NAME già esistente: $existing_instance"
        return 0
    fi
    
    # User data script per setup automatico
    local user_data=$(cat << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update system
apt-get update -y
apt-get upgrade -y

# Install prerequisites
apt-get install -y curl wget unzip jq git docker.io

# Enable and start Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Configure k3s for external access
echo 'K3S_OPTS="--node-external-ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"' >> /etc/systemd/system/k3s.service.env
systemctl restart k3s

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Setup firewall
ufw --force enable
ufw allow ssh
ufw allow 80,443/tcp
ufw allow 30002,30003/tcp

# Optimize for t2.micro
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
sysctl -p

# Setup swap if not exists
if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Clone CRM repository
cd /home/ubuntu
git clone https://github.com/mcatania72/CRM-System_NEW.git
chown -R ubuntu:ubuntu CRM-System_NEW

# Create ready marker
touch /home/ubuntu/setup-complete.txt
EOF
)
    
    # Crea istanza
    log_info "🚀 Avvio istanza EC2 t2.micro..."
    local instance_id=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-groups "$SECURITY_GROUP" \
        --user-data "$user_data" \
        --region "$AWS_REGION" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    log_success "✅ Istanza creata: $instance_id"
    
    # Attendi che l'istanza sia running
    log_info "⏳ Attesa avvio istanza..."
    aws ec2 wait instance-running --instance-ids "$instance_id" --region "$AWS_REGION"
    
    # Ottieni IP pubblico
    local public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    log_success "✅ Istanza avviata"
    echo ""
    echo "=== 🎯 INFORMAZIONI CONNESSIONE ==="
    echo "Instance ID: $instance_id"
    echo "Public IP: $public_ip"
    echo "SSH Command: ssh -i ${KEY_NAME}.pem ubuntu@$public_ip"
    echo ""
    echo "=== ⏳ SETUP IN CORSO ==="
    echo "L'istanza sta completando il setup automatico..."
    echo "Attendere 5-10 minuti prima di connettere"
    echo ""
    echo "Verifica setup completato:"
    echo "ssh -i ${KEY_NAME}.pem ubuntu@$public_ip 'cat setup-complete.txt'"
}

# ================================
# FUNZIONE: ALLOCA ELASTIC IP
# ================================
allocate_elastic_ip() {
    log_info "🌐 Gestione Elastic IP..."
    
    # Lista istanze CRM
    local instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text)
    
    if [ "$instance_id" = "None" ] || [ "$instance_id" = "null" ]; then
        log_error "❌ Nessuna istanza CRM in running trovata"
        exit 1
    fi
    
    # Verifica se esiste già un Elastic IP
    local existing_eip=$(aws ec2 describe-addresses \
        --filters "Name=instance-id,Values=$instance_id" \
        --region "$AWS_REGION" \
        --query 'Addresses[0].PublicIp' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$existing_eip" != "None" ] && [ "$existing_eip" != "null" ]; then
        log_warning "⚠️ Elastic IP già associato: $existing_eip"
        return 0
    fi
    
    # Alloca nuovo Elastic IP
    log_info "📍 Allocazione Elastic IP..."
    local allocation_id=$(aws ec2 allocate-address \
        --domain vpc \
        --region "$AWS_REGION" \
        --query 'AllocationId' \
        --output text)
    
    # Associa Elastic IP all'istanza
    aws ec2 associate-address \
        --instance-id "$instance_id" \
        --allocation-id "$allocation_id" \
        --region "$AWS_REGION"
    
    # Ottieni IP pubblico
    local elastic_ip=$(aws ec2 describe-addresses \
        --allocation-ids "$allocation_id" \
        --region "$AWS_REGION" \
        --query 'Addresses[0].PublicIp' \
        --output text)
    
    log_success "✅ Elastic IP allocato e associato: $elastic_ip"
}

# ================================
# FUNZIONE: VERIFICA SETUP
# ================================
verify_setup() {
    log_info "🔍 Verifica setup AWS..."
    
    # Lista istanze
    echo ""
    echo "=== 🖥️ ISTANZE EC2 ==="
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
        --region "$AWS_REGION" \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
        --output table
    
    # Lista Elastic IP
    echo ""
    echo "=== 🌐 ELASTIC IP ==="
    aws ec2 describe-addresses \
        --region "$AWS_REGION" \
        --query 'Addresses[].[PublicIp,InstanceId,AllocationId]' \
        --output table
    
    # Lista Security Groups
    echo ""
    echo "=== 🛡️ SECURITY GROUPS ==="
    aws ec2 describe-security-groups \
        --group-names "$SECURITY_GROUP" \
        --region "$AWS_REGION" \
        --query 'SecurityGroups[].IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
        --output table
}

# ================================
# FUNZIONE: CLEANUP RISORSE
# ================================
cleanup_resources() {
    log_warning "🗑️ Cleanup risorse AWS..."
    
    # Termina istanza
    local instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$instance_id" != "None" ] && [ "$instance_id" != "null" ]; then
        log_info "🔄 Terminazione istanza $instance_id..."
        aws ec2 terminate-instances --instance-ids "$instance_id" --region "$AWS_REGION"
        aws ec2 wait instance-terminated --instance-ids "$instance_id" --region "$AWS_REGION"
        log_success "✅ Istanza terminata"
    fi
    
    # Release Elastic IP
    local allocation_id=$(aws ec2 describe-addresses \
        --region "$AWS_REGION" \
        --query 'Addresses[0].AllocationId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$allocation_id" != "None" ] && [ "$allocation_id" != "null" ]; then
        log_info "🌐 Release Elastic IP..."
        aws ec2 release-address --allocation-id "$allocation_id" --region "$AWS_REGION"
        log_success "✅ Elastic IP rilasciato"
    fi
    
    # Elimina Security Group
    if aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" --region "$AWS_REGION" &> /dev/null; then
        log_info "🛡️ Eliminazione Security Group..."
        aws ec2 delete-security-group --group-name "$SECURITY_GROUP" --region "$AWS_REGION"
        log_success "✅ Security Group eliminato"
    fi
    
    # Elimina Key Pair
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_info "🔑 Eliminazione Key Pair..."
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION"
        rm -f "${KEY_NAME}.pem"
        log_success "✅ Key Pair eliminato"
    fi
    
    log_success "✅ Cleanup completato"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-help}" in
        "create-instance")
            check_prerequisites
            create_key_pair
            create_security_group
            create_instance
            ;;
        "configure-network")
            check_prerequisites
            allocate_elastic_ip
            ;;
        "verify")
            check_prerequisites
            verify_setup
            ;;
        "cleanup")
            check_prerequisites
            cleanup_resources
            ;;
        "help"|*)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  create-instance    - Crea istanza EC2 t2.micro completa"
            echo "  configure-network  - Configura Elastic IP"
            echo "  verify             - Verifica setup AWS"
            echo "  cleanup            - Elimina tutte le risorse"
            echo ""
            echo "Examples:"
            echo "  $0 create-instance     # Setup completo AWS"
            echo "  $0 configure-network   # Solo Elastic IP"
            echo "  $0 verify              # Verifica risorse"
            echo "  $0 cleanup             # Elimina tutto"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
