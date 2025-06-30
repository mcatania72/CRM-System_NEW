#!/bin/bash

# FASE 6: Script per gestione immagini Docker in k3s
# Import/reimport automatico delle immagini CRM in containerd k3s

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="crm-system"
KUBECTL_CMD="kubectl"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 🐳 FASE 6: Gestione Immagini Docker in k3s ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Function to check Docker images
check_docker_images() {
    echo -e "${BLUE}🔍 Verifica immagini Docker locali...${NC}"
    
    BACKEND_IMAGE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "crm-backend:latest" || echo "")
    FRONTEND_IMAGE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "crm-frontend:latest" || echo "")
    
    if [ -n "$BACKEND_IMAGE" ]; then
        echo -e "${GREEN}✅ Backend image trovata: $BACKEND_IMAGE${NC}"
    else
        echo -e "${RED}❌ Backend image non trovata${NC}"
        return 1
    fi
    
    if [ -n "$FRONTEND_IMAGE" ]; then
        echo -e "${GREEN}✅ Frontend image trovata: $FRONTEND_IMAGE${NC}"
    else
        echo -e "${RED}❌ Frontend image non trovata${NC}"
        return 1
    fi
    
    return 0
}

# Function to check k3s images
check_k3s_images() {
    echo -e "${BLUE}🔍 Verifica immagini k3s containerd...${NC}"
    
    K3S_BACKEND=$(sudo k3s ctr images list | grep "crm-backend:latest" || echo "")
    K3S_FRONTEND=$(sudo k3s ctr images list | grep "crm-frontend:latest" || echo "")
    
    if [ -n "$K3S_BACKEND" ]; then
        echo -e "${GREEN}✅ Backend image in k3s: OK${NC}"
    else
        echo -e "${RED}❌ Backend image mancante in k3s${NC}"
        return 1
    fi
    
    if [ -n "$K3S_FRONTEND" ]; then
        echo -e "${GREEN}✅ Frontend image in k3s: OK${NC}"
    else
        echo -e "${RED}❌ Frontend image mancante in k3s${NC}"
        return 1
    fi
    
    return 0
}

# Function to import images into k3s
import_images_to_k3s() {
    echo -e "${BLUE}📥 Import immagini Docker in k3s...${NC}"
    
    # Check if Docker images exist
    if ! check_docker_images; then
        echo -e "${RED}❌ Immagini Docker non disponibili. Prima esegui build!${NC}"
        return 1
    fi
    
    # Create temp directory
    TEMP_DIR="/tmp/k3s-images-$$"
    mkdir -p "$TEMP_DIR"
    
    echo "Directory temporanea: $TEMP_DIR"
    
    # Export backend image
    echo "Export backend image..."
    if docker save crm-backend:latest -o "$TEMP_DIR/crm-backend.tar"; then
        echo -e "${GREEN}✅ Backend image esportata${NC}"
    else
        echo -e "${RED}❌ Errore export backend image${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Export frontend image
    echo "Export frontend image..."
    if docker save crm-frontend:latest -o "$TEMP_DIR/crm-frontend.tar"; then
        echo -e "${GREEN}✅ Frontend image esportata${NC}"
    else
        echo -e "${RED}❌ Errore export frontend image${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Import into k3s
    echo "Import backend in k3s..."
    if sudo k3s ctr images import "$TEMP_DIR/crm-backend.tar"; then
        echo -e "${GREEN}✅ Backend image importata in k3s${NC}"
    else
        echo -e "${RED}❌ Errore import backend in k3s${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    echo "Import frontend in k3s..."
    if sudo k3s ctr images import "$TEMP_DIR/crm-frontend.tar"; then
        echo -e "${GREEN}✅ Frontend image importata in k3s${NC}"
    else
        echo -e "${RED}❌ Errore import frontend in k3s${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✅ Cleanup temporaneo completato${NC}"
    
    return 0
}

# Function to restart deployments after image import
restart_deployments() {
    echo -e "${BLUE}🔄 Restart deployments per usare nuove immagini...${NC}"
    
    # Check if namespace exists
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE non esiste${NC}"
        return 0
    fi
    
    # Delete pods to force recreation with new images
    echo "Force restart backend pods..."
    $KUBECTL_CMD delete pods -n $NAMESPACE -l app=backend --force --grace-period=0 2>/dev/null || true
    
    echo "Force restart frontend pods..."
    $KUBECTL_CMD delete pods -n $NAMESPACE -l app=frontend --force --grace-period=0 2>/dev/null || true
    
    # Wait a moment
    sleep 5
    
    # Check new pods status
    echo "Verifica nuovi pod..."
    $KUBECTL_CMD get pods -n $NAMESPACE
    
    echo -e "${GREEN}✅ Deployments riavviati${NC}"
}

# Function to build and import images
build_and_import() {
    echo -e "${BLUE}🔨 Build e import completo delle immagini...${NC}"
    
    # Check if we're in the correct directory structure
    if [ ! -d "../backend" ] || [ ! -d "../frontend" ]; then
        echo -e "${RED}❌ Directory backend/frontend non trovate${NC}"
        echo "Esegui questo script da devops-pipeline-fase-6/"
        return 1
    fi
    
    # Build backend
    echo "Build backend image..."
    cd ../backend
    if docker build -t crm-backend:latest .; then
        echo -e "${GREEN}✅ Backend build completato${NC}"
    else
        echo -e "${RED}❌ Backend build fallito${NC}"
        cd ../devops-pipeline-fase-6
        return 1
    fi
    
    # Build frontend
    echo "Build frontend image..."
    cd ../frontend
    if docker build -t crm-frontend:latest .; then
        echo -e "${GREEN}✅ Frontend build completato${NC}"
    else
        echo -e "${RED}❌ Frontend build fallito${NC}"
        cd ../devops-pipeline-fase-6
        return 1
    fi
    
    # Return to fase-6 directory
    cd ../devops-pipeline-fase-6
    
    # Import into k3s
    import_images_to_k3s
    
    return 0
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Status immagini Docker e k3s${NC}"
    echo ""
    
    echo -e "${YELLOW}=== Immagini Docker ===${NC}"
    docker images | grep -E "(REPOSITORY|crm-)" || echo "Nessuna immagine CRM trovata"
    
    echo ""
    echo -e "${YELLOW}=== Immagini k3s containerd ===${NC}"
    sudo k3s ctr images list | grep -E "(REF|crm-)" || echo "Nessuna immagine CRM in k3s"
    
    echo ""
    echo -e "${YELLOW}=== Pod status ===${NC}"
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        $KUBECTL_CMD get pods -n $NAMESPACE
    else
        echo "Namespace $NAMESPACE non esiste"
    fi
}

# Function to cleanup images
cleanup_images() {
    echo -e "${BLUE}🗑️  Cleanup immagini CRM...${NC}"
    
    read -p "Rimuovere immagini Docker CRM? (y/n): " remove_docker
    if [ "$remove_docker" = "y" ] || [ "$remove_docker" = "Y" ]; then
        echo "Rimozione immagini Docker..."
        docker images | grep "crm-" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
        echo -e "${GREEN}✅ Immagini Docker rimosse${NC}"
    fi
    
    read -p "Rimuovere immagini k3s CRM? (y/n): " remove_k3s
    if [ "$remove_k3s" = "y" ] || [ "$remove_k3s" = "Y" ]; then
        echo "Rimozione immagini k3s..."
        sudo k3s ctr images list | grep "crm-" | awk '{print $1}' | while read img; do
            sudo k3s ctr images rm "$img" 2>/dev/null || true
        done
        echo -e "${GREEN}✅ Immagini k3s rimosse${NC}"
    fi
}

# Main execution
main() {
    local command=${1:-status}
    
    case $command in
        import)
            import_images_to_k3s
            restart_deployments
            ;;
        build)
            build_and_import
            restart_deployments
            ;;
        restart)
            restart_deployments
            ;;
        status)
            show_status
            ;;
        check)
            echo "Verifica immagini Docker..."
            check_docker_images
            echo ""
            echo "Verifica immagini k3s..."
            check_k3s_images
            ;;
        cleanup)
            cleanup_images
            ;;
        fix)
            echo -e "${BLUE}🔧 FIX: Import e restart automatico${NC}"
            if ! check_k3s_images; then
                echo "Immagini mancanti in k3s, import automatico..."
                import_images_to_k3s
            fi
            restart_deployments
            ;;
        help|--help|-h)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  status     Mostra status immagini (default)"
            echo "  check      Verifica disponibilità immagini"
            echo "  import     Import immagini Docker in k3s"
            echo "  build      Build e import completo"
            echo "  restart    Restart deployment per nuove immagini"
            echo "  fix        Fix automatico immagini mancanti"
            echo "  cleanup    Rimuovi immagini CRM"
            echo "  help       Mostra questo aiuto"
            echo ""
            echo "Examples:"
            echo "  $0 status     # Stato attuale"
            echo "  $0 check      # Verifica immagini"
            echo "  $0 import     # Import in k3s"
            echo "  $0 fix        # Fix automatico"
            ;;
        *)
            echo -e "${RED}❌ Comando sconosciuto: $command${NC}"
            echo "Usa '$0 help' per informazioni"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
