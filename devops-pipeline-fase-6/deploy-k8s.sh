#!/bin/bash

# FASE 6: Deploy CRM System su Kubernetes
# Gestisce il deployment completo dell'applicazione CRM su k3s

set -e  # Exit on any error

# Colors per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="crm-system"
LOG_FILE="$HOME/deploy-k8s.log"
KUBECTL_CMD="kubectl"

# Check if we need to use sudo k3s kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

# Logging setup
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}=== ☸️  FASE 6: Kubernetes Deployment ===${NC}"
echo "Timestamp: $(date)"
echo "Namespace: $NAMESPACE"
echo "Kubectl: $KUBECTL_CMD"
echo ""

# Function to wait for deployment rollout
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-300}  # 5 minutes default
    
    echo -e "${BLUE}⏳ Waiting for deployment: $deployment${NC}"
    
    if $KUBECTL_CMD rollout status deployment/$deployment -n $NAMESPACE --timeout=${timeout}s; then
        echo -e "${GREEN}✅ Deployment $deployment is ready${NC}"
        return 0
    else
        echo -e "${RED}❌ Deployment $deployment failed or timed out${NC}"
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local label_selector=$1
    local timeout=${2:-300}
    
    echo -e "${BLUE}⏳ Waiting for pods: $label_selector${NC}"
    
    if $KUBECTL_CMD wait --for=condition=ready pod -l $label_selector -n $NAMESPACE --timeout=${timeout}s; then
        echo -e "${GREEN}✅ Pods ready: $label_selector${NC}"
        return 0
    else
        echo -e "${RED}❌ Pods not ready: $label_selector${NC}"
        return 1
    fi
}

# Function to check service endpoints
check_service_endpoints() {
    local service=$1
    
    echo -e "${BLUE}🔍 Checking service endpoints: $service${NC}"
    
    local endpoints=$($KUBECTL_CMD get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [ -n "$endpoints" ]; then
        echo -e "${GREEN}✅ Service $service has endpoints: $endpoints${NC}"
        return 0
    else
        echo -e "${RED}❌ Service $service has no endpoints${NC}"
        return 1
    fi
}

# Function to build container images
build_images() {
    echo -e "${BLUE}🔨 Building container images...${NC}"
    
    # Check if we're in the correct directory
    if [ ! -d "../backend" ] || [ ! -d "../frontend" ]; then
        echo -e "${RED}❌ Backend/Frontend directories not found${NC}"
        echo "Please run this script from devops-pipeline-fase-6 directory"
        exit 1
    fi
    
    # Build backend image
    echo -e "${BLUE}Building backend image...${NC}"
    cd ../backend
    if docker build -t crm-backend:latest .; then
        echo -e "${GREEN}✅ Backend image built successfully${NC}"
    else
        echo -e "${RED}❌ Backend image build failed${NC}"
        exit 1
    fi
    
    # Build frontend image
    echo -e "${BLUE}Building frontend image...${NC}"
    cd ../frontend
    if docker build -t crm-frontend:latest .; then
        echo -e "${GREEN}✅ Frontend image built successfully${NC}"
    else
        echo -e "${RED}❌ Frontend image build failed${NC}"
        exit 1
    fi
    
    cd ../devops-pipeline-fase-6
    echo -e "${GREEN}✅ All images built successfully${NC}"
}

# Function to configure local image usage
configure_local_images() {
    echo -e "${BLUE}🔧 Configuring deployments to use local images...${NC}"
    
    # Wait a moment for deployments to be created
    sleep 5
    
    # Check if deployments exist and patch them to use local images
    if $KUBECTL_CMD get deployment backend -n $NAMESPACE &>/dev/null; then
        echo "Configuring backend to use local images..."
        $KUBECTL_CMD patch deployment backend -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","imagePullPolicy":"IfNotPresent"}]}}}}' || true
    fi
    
    if $KUBECTL_CMD get deployment frontend -n $NAMESPACE &>/dev/null; then
        echo "Configuring frontend to use local images..."
        $KUBECTL_CMD patch deployment frontend -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"frontend","imagePullPolicy":"IfNotPresent"}]}}}}' || true
    fi
    
    echo -e "${GREEN}✅ Local image configuration applied${NC}"
}

# Function to apply Kubernetes manifests
apply_manifests() {
    echo -e "${BLUE}📋 Applying Kubernetes manifests...${NC}"
    
    local manifest_dir="k8s"
    
    if [ ! -d "$manifest_dir" ]; then
        echo -e "${RED}❌ Manifests directory not found: $manifest_dir${NC}"
        exit 1
    fi
    
    # Apply manifests in CORRECT order (services BEFORE deployments)
    local manifests=(
        "01-namespace.yaml"
        "02-secrets.yaml"
        "03-postgres-pvc.yaml"
        "05-postgres-service.yaml"      # ← SERVICE PRIMA DEL DEPLOYMENT!
        "04-postgres-deployment.yaml"   # ← DEPLOYMENT DOPO IL SERVICE!
        "07-backend-service.yaml"       # ← SERVICE PRIMA DEL DEPLOYMENT!
        "06-backend-deployment.yaml"    # ← DEPLOYMENT DOPO IL SERVICE!
        "09-frontend-service.yaml"      # ← SERVICE PRIMA DEL DEPLOYMENT!
        "08-frontend-deployment.yaml"   # ← DEPLOYMENT DOPO IL SERVICE!
        "10-ingress.yaml"
        "11-autoscaling.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        local file="$manifest_dir/$manifest"
        if [ -f "$file" ]; then
            echo -e "${BLUE}Applying: $manifest${NC}"
            if $KUBECTL_CMD apply -f "$file"; then
                echo -e "${GREEN}✅ Applied: $manifest${NC}"
            else
                echo -e "${RED}❌ Failed to apply: $manifest${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}⚠️  Manifest not found: $file${NC}"
        fi
    done
    
    # Configure local images after applying manifests
    configure_local_images
}

# Function to perform health checks
health_checks() {
    echo -e "${BLUE}🏥 Performing health checks...${NC}"
    
    # Check namespace
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✅ Namespace $NAMESPACE exists${NC}"
    else
        echo -e "${RED}❌ Namespace $NAMESPACE not found${NC}"
        return 1
    fi
    
    # Check PVC
    echo -e "${BLUE}Checking PersistentVolumeClaim...${NC}"
    local pvc_status=$($KUBECTL_CMD get pvc postgres-pvc -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$pvc_status" = "Bound" ]; then
        echo -e "${GREEN}✅ PVC postgres-pvc is bound${NC}"
    else
        echo -e "${RED}❌ PVC postgres-pvc status: $pvc_status${NC}"
    fi
    
    # Check deployments
    echo -e "${BLUE}Checking deployments...${NC}"
    $KUBECTL_CMD get deployments -n $NAMESPACE
    
    # Check pods
    echo -e "${BLUE}Checking pods...${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE
    
    # Check services
    echo -e "${BLUE}Checking services...${NC}"
    $KUBECTL_CMD get services -n $NAMESPACE
}

# Function to show access information
show_access_info() {
    echo -e "${PURPLE}=== 🌐 ACCESS INFORMATION ===${NC}"
    
    # Get LoadBalancer IP
    local lb_ip=$($KUBECTL_CMD get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "192.168.1.29")
    
    # Get NodePort services
    local frontend_nodeport=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")
    local backend_nodeport=$($KUBECTL_CMD get svc backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30003")
    
    echo ""
    echo -e "${GREEN}🎨 Frontend Access:${NC}"
    echo "   NodePort:     http://$lb_ip:$frontend_nodeport"
    echo "   Port Forward: kubectl port-forward -n $NAMESPACE svc/frontend-service 3000:80"
    echo ""
    echo -e "${GREEN}🔌 Backend API:${NC}"
    echo "   NodePort:     http://$lb_ip:$backend_nodeport"
    echo "   Port Forward: kubectl port-forward -n $NAMESPACE svc/backend-service 3001:4001"
    echo ""
    echo -e "${GREEN}🔑 Login Credentials:${NC}"
    echo "   Email:    admin@crm.local"
    echo "   Password: admin123"
    echo ""
    echo -e "${GREEN}🛠️  Kubernetes Commands:${NC}"
    echo "   Status:   $KUBECTL_CMD get all -n $NAMESPACE"
    echo "   Logs:     $KUBECTL_CMD logs -f deployment/backend -n $NAMESPACE"
    echo "   Scale:    $KUBECTL_CMD scale deployment backend --replicas=3 -n $NAMESPACE"
    echo ""
}

# Function to start deployment
start_deployment() {
    echo -e "${GREEN}🚀 Starting CRM Kubernetes deployment...${NC}"
    
    # Build images
    build_images
    
    # Apply manifests
    apply_manifests
    
    echo -e "${BLUE}⏳ Waiting for deployments to be ready...${NC}"
    
    # Wait for PostgreSQL first
    wait_for_deployment postgres 600  # 10 minutes for database
    wait_for_pods "app=postgres" 120
    check_service_endpoints postgres-service
    
    # Wait for backend
    wait_for_deployment backend 300
    wait_for_pods "app=backend" 120
    check_service_endpoints backend-service
    
    # Wait for frontend
    wait_for_deployment frontend 180
    wait_for_pods "app=frontend" 60
    check_service_endpoints frontend-service
    
    # Health checks
    health_checks
    
    # Show access info
    show_access_info
    
    echo -e "${GREEN}✅ CRM Kubernetes deployment completed successfully!${NC}"
}

# Function to stop deployment
stop_deployment() {
    echo -e "${YELLOW}🛑 Stopping CRM Kubernetes deployment...${NC}"
    
    # Scale deployments to 0
    echo "Scaling deployments to 0 replicas..."
    $KUBECTL_CMD scale deployment --all --replicas=0 -n $NAMESPACE 2>/dev/null || true
    
    # Wait for pods to terminate
    echo "Waiting for pods to terminate..."
    $KUBECTL_CMD wait --for=delete pod --all -n $NAMESPACE --timeout=300s 2>/dev/null || true
    
    echo -e "${GREEN}✅ CRM deployment stopped${NC}"
}

# Function to restart deployment
restart_deployment() {
    echo -e "${BLUE}🔄 Restarting CRM Kubernetes deployment...${NC}"
    
    # Restart deployments
    $KUBECTL_CMD rollout restart deployment/postgres -n $NAMESPACE
    $KUBECTL_CMD rollout restart deployment/backend -n $NAMESPACE
    $KUBECTL_CMD rollout restart deployment/frontend -n $NAMESPACE
    
    # Wait for rollouts
    wait_for_deployment postgres 300
    wait_for_deployment backend 300
    wait_for_deployment frontend 180
    
    echo -e "${GREEN}✅ CRM deployment restarted${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 CRM Kubernetes Status${NC}"
    echo ""
    
    # Check if namespace exists
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE not found${NC}"
        echo "Run: ./deploy-k8s.sh start"
        return 1
    fi
    
    echo -e "${GREEN}📦 Deployments:${NC}"
    $KUBECTL_CMD get deployments -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}🏃 Pods:${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}🔗 Services:${NC}"
    $KUBECTL_CMD get services -n $NAMESPACE -o wide
    echo ""
    
    echo -e "${GREEN}💾 Storage:${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE
    echo ""
    
    echo -e "${GREEN}🌐 Ingress:${NC}"
    $KUBECTL_CMD get ingress -n $NAMESPACE 2>/dev/null || echo "No ingress resources found"
    echo ""
    
    # Resource usage
    echo -e "${GREEN}📈 Resource Usage:${NC}"
    $KUBECTL_CMD top pods -n $NAMESPACE 2>/dev/null || echo "Metrics not available (install metrics-server)"
    
    show_access_info
}

# Function to show logs
show_logs() {
    local component=${1:-all}
    
    echo -e "${BLUE}📋 Showing logs for: $component${NC}"
    
    case $component in
        postgres|db)
            $KUBECTL_CMD logs -f deployment/postgres -n $NAMESPACE
            ;;
        backend|api)
            $KUBECTL_CMD logs -f deployment/backend -n $NAMESPACE
            ;;
        frontend|web)
            $KUBECTL_CMD logs -f deployment/frontend -n $NAMESPACE
            ;;
        all|*)
            echo "Available components: postgres, backend, frontend"
            echo "Recent logs from all components:"
            echo ""
            echo -e "${YELLOW}=== PostgreSQL Logs ===${NC}"
            $KUBECTL_CMD logs --tail=20 deployment/postgres -n $NAMESPACE 2>/dev/null || echo "PostgreSQL not running"
            echo ""
            echo -e "${YELLOW}=== Backend Logs ===${NC}"
            $KUBECTL_CMD logs --tail=20 deployment/backend -n $NAMESPACE 2>/dev/null || echo "Backend not running"
            echo ""
            echo -e "${YELLOW}=== Frontend Logs ===${NC}"
            $KUBECTL_CMD logs --tail=20 deployment/frontend -n $NAMESPACE 2>/dev/null || echo "Frontend not running"
            ;;
    esac
}

# Function to scale deployment
scale_deployment() {
    local replicas=${1:-2}
    
    echo -e "${BLUE}📈 Scaling deployments to $replicas replicas...${NC}"
    
    # Scale backend and frontend (not PostgreSQL)
    $KUBECTL_CMD scale deployment backend --replicas=$replicas -n $NAMESPACE
    $KUBECTL_CMD scale deployment frontend --replicas=$replicas -n $NAMESPACE
    
    # Wait for scaling
    wait_for_deployment backend 180
    wait_for_deployment frontend 120
    
    echo -e "${GREEN}✅ Scaling completed${NC}"
    show_status
}

# Main execution
main() {
    local command=${1:-start}
    
    case $command in
        start)
            start_deployment
            ;;
        stop)
            stop_deployment
            ;;
        restart)
            restart_deployment
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs ${2:-all}
            ;;
        scale)
            scale_deployment ${2:-2}
            ;;
        build)
            build_images
            ;;
        apply)
            apply_manifests
            ;;
        help|--help|-h)
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  start          Start CRM deployment (default)"
            echo "  stop           Stop CRM deployment"
            echo "  restart        Restart CRM deployment"
            echo "  status         Show deployment status"
            echo "  logs [component] Show logs (postgres|backend|frontend|all)"
            echo "  scale [replicas] Scale backend/frontend replicas"
            echo "  build          Build container images only"
            echo "  apply          Apply K8s manifests only"
            echo "  help           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 start       # Deploy CRM to Kubernetes"
            echo "  $0 status      # Check deployment status"
            echo "  $0 logs backend # Show backend logs"
            echo "  $0 scale 3     # Scale to 3 replicas"
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
