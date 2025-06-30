#!/bin/bash

# FASE 6: Sync DevOps Configuration da GitHub
# Scarica e sincronizza la configurazione FASE 6 dal repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/mcatania72/CRM-System_NEW.git"
TARGET_DIR="$HOME/Claude"
FASE_DIR="devops-pipeline-fase-6"
LOG_FILE="$HOME/sync-devops-fase6.log"

# Logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}=== 🔄 FASE 6: DevOps Configuration Sync ===${NC}"
echo "Repository: $REPO_URL"
echo "Target Directory: $TARGET_DIR"
echo "Timestamp: $(date)"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git is not installed${NC}"
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "${RED}❌ Cannot reach GitHub${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites satisfied${NC}"
}

# Function to backup existing configuration
backup_existing() {
    if [ -d "$TARGET_DIR/$FASE_DIR" ]; then
        echo -e "${BLUE}💾 Backing up existing FASE 6 configuration...${NC}"
        
        local backup_dir="$TARGET_DIR/${FASE_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
        mv "$TARGET_DIR/$FASE_DIR" "$backup_dir"
        
        echo -e "${GREEN}✅ Backup created: $backup_dir${NC}"
    fi
}

# Function to clone or update repository
sync_repository() {
    echo -e "${BLUE}📥 Syncing repository...${NC}"
    
    # Create target directory if it doesn't exist
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
    
    if [ -d ".git" ]; then
        echo "Repository exists, updating..."
        git fetch origin
        git reset --hard origin/main
        git pull origin main
    else
        echo "Cloning repository..."
        git clone "$REPO_URL" .
    fi
    
    echo -e "${GREEN}✅ Repository synced${NC}"
}

# Function to verify FASE 6 structure
verify_structure() {
    echo -e "${BLUE}🔍 Verifying FASE 6 structure...${NC}"
    
    local required_files=(
        "$FASE_DIR/README.md"
        "$FASE_DIR/prerequisites-k8s.sh"
        "$FASE_DIR/deploy-k8s.sh"
        "$FASE_DIR/test-k8s.sh"
        "$FASE_DIR/Jenkinsfile"
        "$FASE_DIR/k8s/01-namespace.yaml"
        "$FASE_DIR/k8s/04-postgres-deployment.yaml"
        "$FASE_DIR/k8s/06-backend-deployment.yaml"
        "$FASE_DIR/k8s/08-frontend-deployment.yaml"
    )
    
    local missing_files=0
    
    for file in "${required_files[@]}"; do
        if [ -f "$TARGET_DIR/$file" ]; then
            echo -e "${GREEN}✅ $file${NC}"
        else
            echo -e "${RED}❌ $file${NC}"
            missing_files=$((missing_files + 1))
        fi
    done
    
    if [ $missing_files -eq 0 ]; then
        echo -e "${GREEN}✅ All required files present${NC}"
    else
        echo -e "${RED}❌ $missing_files files missing${NC}"
        exit 1
    fi
}

# Function to set permissions
set_permissions() {
    echo -e "${BLUE}🔧 Setting file permissions...${NC}"
    
    cd "$TARGET_DIR/$FASE_DIR"
    
    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
    chmod +x scripts/*.sh 2>/dev/null || true
    
    # Set appropriate permissions for YAML files
    chmod 644 k8s/*.yaml 2>/dev/null || true
    chmod 644 profiles/*.yaml 2>/dev/null || true
    
    echo -e "${GREEN}✅ Permissions set${NC}"
}

# Function to create symlinks
create_symlinks() {
    echo -e "${BLUE}🔗 Creating symlinks...${NC}"
    
    # Create symlink to FASE 6 scripts
    local link_dir="$HOME/devops-scripts-fase6"
    
    if [ -L "$link_dir" ]; then
        rm "$link_dir"
    fi
    
    ln -sf "$TARGET_DIR/$FASE_DIR" "$link_dir"
    
    echo -e "${GREEN}✅ Symlink created: $link_dir${NC}"
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo -e "${BLUE}=== 🎯 NEXT STEPS ===${NC}"
    echo ""
    echo -e "${GREEN}1. Verify Kubernetes prerequisites:${NC}"
    echo "   cd $TARGET_DIR/$FASE_DIR"
    echo "   ./prerequisites-k8s.sh"
    echo ""
    echo -e "${GREEN}2. Deploy CRM to Kubernetes:${NC}"
    echo "   ./deploy-k8s.sh start"
    echo ""
    echo -e "${GREEN}3. Run tests:${NC}"
    echo "   ./test-k8s.sh"
    echo ""
    echo -e "${GREEN}4. Access application:${NC}"
    echo "   Frontend: http://192.168.1.29:30002"
    echo "   Backend API: http://192.168.1.29:30003/api"
    echo "   Login: admin@crm.local / admin123"
    echo ""
    echo -e "${GREEN}5. Check status:${NC}"
    echo "   ./deploy-k8s.sh status"
    echo ""
    echo -e "${YELLOW}📁 Working directories:${NC}"
    echo "   Main: $TARGET_DIR/$FASE_DIR"
    echo "   Symlink: $HOME/devops-scripts-fase6"
    echo ""
    echo -e "${YELLOW}📋 Log file:${NC}"
    echo "   $LOG_FILE"
    echo ""
}

# Function to run basic validation
run_validation() {
    echo -e "${BLUE}🧪 Running basic validation...${NC}"
    
    cd "$TARGET_DIR/$FASE_DIR"
    
    # Check if k3s is running
    if systemctl is-active --quiet k3s; then
        echo -e "${GREEN}✅ k3s service is active${NC}"
        
        # Quick cluster check
        if sudo k3s kubectl cluster-info &>/dev/null; then
            echo -e "${GREEN}✅ Kubernetes cluster is responding${NC}"
        else
            echo -e "${YELLOW}⚠️  Kubernetes cluster check failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  k3s service is not active${NC}"
        echo "   Run: sudo systemctl start k3s"
    fi
    
    # Check Docker
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✅ Docker service is active${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker service is not active${NC}"
    fi
    
    # Check available resources
    local mem_available=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    echo "💾 Available memory: ${mem_available}GB"
    
    if (( $(echo "$mem_available > 8" | bc -l) )); then
        echo -e "${GREEN}✅ Sufficient memory for deployment${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited memory, consider resource optimization${NC}"
    fi
}

# Main execution
main() {
    local action=${1:-sync}
    
    case $action in
        sync|update|"")
            check_prerequisites
            backup_existing
            sync_repository
            verify_structure
            set_permissions
            create_symlinks
            run_validation
            show_next_steps
            ;;
        verify)
            verify_structure
            ;;
        permissions)
            set_permissions
            ;;
        validate)
            run_validation
            ;;
        clean)
            echo -e "${YELLOW}⚠️  Removing FASE 6 configuration...${NC}"
            read -p "Are you sure? (y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -rf "$TARGET_DIR/$FASE_DIR"
                rm -f "$HOME/devops-scripts-fase6"
                echo -e "${GREEN}✅ FASE 6 configuration removed${NC}"
            fi
            ;;
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  sync         Sync FASE 6 configuration from GitHub (default)"
            echo "  update       Same as sync"
            echo "  verify       Verify FASE 6 file structure"
            echo "  permissions  Set correct file permissions"
            echo "  validate     Run basic environment validation"
            echo "  clean        Remove FASE 6 configuration"
            echo "  help         Show this help"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown action: $action${NC}"
            echo "Use '$0 help' for available actions"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ FASE 6 sync completed successfully!${NC}"
    echo "Log saved to: $LOG_FILE"
}

# Execute main function
main "$@"
