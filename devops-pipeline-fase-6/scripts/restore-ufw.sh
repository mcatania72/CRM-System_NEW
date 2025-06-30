#!/bin/bash

# FASE 6: Ripristino Regole UFW da backup conversation
# Ripristina tutte le regole UFW basandosi sui log precedenti

set -euo pipefail

echo "=== 🔥 RIPRISTINO REGOLE UFW COMPLETE ==="
echo "Timestamp: $(date)"
echo ""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

restore_ufw_rules() {
    echo -e "${BLUE}🔄 Ripristino regole UFW complete...${NC}"
    
    # Reset UFW to clean state
    echo "Reset UFW..."
    sudo ufw --force reset
    
    # Basic SSH access
    echo "Regole base SSH..."
    sudo ufw allow ssh
    sudo ufw allow 22/tcp
    
    # Jenkins
    echo "Jenkins (8080)..."
    sudo ufw allow 8080/tcp comment 'Jenkins'
    
    # Kubernetes API
    echo "Kubernetes API (6443)..."
    sudo ufw allow 6443/tcp comment 'Kubernetes API'
    
    # HTTP/HTTPS
    echo "HTTP/HTTPS..."
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    
    # Kubernetes kubelet
    echo "Kubernetes kubelet (10250)..."
    sudo ufw allow 10250/tcp comment 'Kubernetes kubelet'
    
    # Development ports
    echo "Development ports..."
    sudo ufw allow 3000/tcp comment 'Dev port 3000'
    sudo ufw allow 3001/tcp comment 'Dev port 3001'
    
    # SonarQube
    echo "SonarQube (9000)..."
    sudo ufw allow 9000/tcp comment 'SonarQube'
    
    # CRM PostgreSQL System ranges
    echo "CRM PostgreSQL System ranges..."
    sudo ufw allow 4000:4002/tcp comment 'CRM PostgreSQL System'
    sudo ufw allow 4000:4010/tcp comment 'CRM PostgreSQL System'
    
    # CRM Kubernetes NodePorts
    echo "CRM Kubernetes NodePorts..."
    sudo ufw allow 30002/tcp comment 'CRM Frontend K8s NodePort'
    sudo ufw allow 30003/tcp comment 'CRM Backend K8s NodePort'
    
    # Enable UFW
    echo "Abilitazione UFW..."
    sudo ufw --force enable
    
    echo -e "${GREEN}✅ Regole UFW ripristinate${NC}"
}

verify_rules() {
    echo -e "${BLUE}🔍 Verifica regole applicate...${NC}"
    
    echo "UFW Status completo:"
    sudo ufw status numbered
    echo ""
    
    echo "Verifica porte critiche in ascolto:"
    sudo netstat -tulpn | grep -E ":(22|8080|9000|30002|30003)" || echo "Alcune porte potrebbero non essere ancora in ascolto"
}

backup_current_rules() {
    echo -e "${BLUE}💾 Backup regole attuali (se esistenti)...${NC}"
    
    # Create backup directory
    mkdir -p /tmp/ufw-backup-$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="/tmp/ufw-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Backup current rules if any
    sudo ufw status numbered > "$BACKUP_DIR/ufw-rules-before.txt" 2>/dev/null || echo "No existing rules to backup"
    sudo iptables-save > "$BACKUP_DIR/iptables-before.txt" 2>/dev/null || echo "Could not backup iptables"
    
    echo "Backup salvato in: $BACKUP_DIR"
    echo -e "${GREEN}✅ Backup completato${NC}"
}

show_access_info() {
    echo ""
    echo -e "${YELLOW}🌐 PORTE RIPRISTINATE:${NC}"
    echo "SSH: 22"
    echo "HTTP: 80"
    echo "HTTPS: 443"
    echo "Jenkins: 8080"
    echo "SonarQube: 9000"
    echo "Dev ports: 3000, 3001"
    echo "Kubernetes API: 6443"
    echo "Kubernetes kubelet: 10250"
    echo "CRM PostgreSQL: 4000-4002, 4000-4010"
    echo "CRM Frontend: 30002"
    echo "CRM Backend: 30003"
    echo ""
    echo "Test accesso CRM:"
    echo "Frontend: http://192.168.1.29:30002"
    echo "Backend: http://192.168.1.29:30003/api"
}

# Main execution
case "${1:-full}" in
    "backup")
        backup_current_rules
        ;;
    "restore")
        restore_ufw_rules
        verify_rules
        ;;
    "verify")
        verify_rules
        ;;
    "full")
        backup_current_rules
        echo ""
        restore_ufw_rules
        echo ""
        verify_rules
        show_access_info
        ;;
    *)
        echo "Usage: $0 [backup|restore|verify|full]"
        echo ""
        echo "  backup  - Backup regole attuali"
        echo "  restore - Ripristina tutte le regole"
        echo "  verify  - Verifica regole applicate"
        echo "  full    - Esegue tutto (default)"
        ;;
esac

echo ""
echo "=== Ripristino UFW completato ==="
