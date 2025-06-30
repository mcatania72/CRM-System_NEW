#!/bin/bash

# FASE 6: Script per gestione scaling Kubernetes
# Gestisce scaling automatico e manuale dei deployments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
NAMESPACE="crm-system"
KUBECTL_CMD="kubectl"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 📈 FASE 6: Kubernetes Scaling Management ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Kubectl: $KUBECTL_CMD"
echo ""

# Function to get current replica counts
get_current_replicas() {
    local deployment=$1
    $KUBECTL_CMD get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

# Function to get ready replica counts
get_ready_replicas() {
    local deployment=$1
    $KUBECTL_CMD get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"
}

# Function to show current scaling status
show_scaling_status() {
    echo -e "${BLUE}📊 Current Scaling Status${NC}"
    echo ""
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE not found${NC}"
        return 1
    fi
    
    local deployments=("postgres" "backend" "frontend")
    
    for deployment in "${deployments[@]}"; do
        if $KUBECTL_CMD get deployment $deployment -n $NAMESPACE &>/dev/null; then
            local current=$(get_current_replicas $deployment)
            local ready=$(get_ready_replicas $deployment)
            
            echo -e "${GREEN}📦 $deployment:${NC}"
            echo "   Desired: $current replicas"
            echo "   Ready:   $ready replicas"
            
            if [ "$current" -eq "$ready" ]; then
                echo -e "   Status:  ${GREEN}✅ Healthy${NC}"
            else
                echo -e "   Status:  ${YELLOW}⚠️  Scaling in progress${NC}"
            fi
            echo ""
        else
            echo -e "${RED}❌ Deployment $deployment not found${NC}"
        fi
    done
    
    # Show HPA status if available
    echo -e "${BLUE}🎯 Horizontal Pod Autoscaler Status${NC}"
    if $KUBECTL_CMD get hpa -n $NAMESPACE &>/dev/null; then
        $KUBECTL_CMD get hpa -n $NAMESPACE
    else
        echo "No HPA configured"
    fi
    echo ""
    
    # Show resource usage if available
    echo -e "${BLUE}📈 Resource Usage${NC}"
    if $KUBECTL_CMD top pods -n $NAMESPACE &>/dev/null; then
        $KUBECTL_CMD top pods -n $NAMESPACE
    else
        echo "Metrics not available"
    fi
}

# Function to scale a specific deployment
scale_deployment() {
    local deployment=$1
    local replicas=$2
    
    echo -e "${BLUE}📈 Scaling $deployment to $replicas replicas...${NC}"
    
    if ! $KUBECTL_CMD get deployment $deployment -n $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Deployment $deployment not found${NC}"
        return 1
    fi
    
    # Special handling for PostgreSQL
    if [ "$deployment" = "postgres" ] && [ "$replicas" -gt 1 ]; then
        echo -e "${YELLOW}⚠️  WARNING: PostgreSQL should typically run with 1 replica${NC}"
        echo "Multiple PostgreSQL replicas require special configuration for data consistency."
        read -p "Continue anyway? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Scaling cancelled"
            return 0
        fi
    fi
    
    # Perform scaling
    if $KUBECTL_CMD scale deployment $deployment --replicas=$replicas -n $NAMESPACE; then
        echo -e "${GREEN}✅ Scaling command issued${NC}"
        
        # Wait for scaling to complete
        echo "Waiting for scaling to complete..."
        if $KUBECTL_CMD rollout status deployment/$deployment -n $NAMESPACE --timeout=300s; then
            echo -e "${GREEN}✅ $deployment scaled successfully to $replicas replicas${NC}"
        else
            echo -e "${RED}❌ Scaling timed out or failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Scaling command failed${NC}"
        return 1
    fi
}

# Function to scale all deployments
scale_all() {
    local backend_replicas=${1:-2}
    local frontend_replicas=${2:-2}
    
    echo -e "${BLUE}📈 Scaling all deployments...${NC}"
    echo "Backend: $backend_replicas replicas"
    echo "Frontend: $frontend_replicas replicas"
    echo "PostgreSQL: 1 replica (unchanged)"
    echo ""
    
    # Scale backend
    scale_deployment "backend" "$backend_replicas"
    
    # Scale frontend
    scale_deployment "frontend" "$frontend_replicas"
    
    echo -e "${GREEN}✅ All deployments scaled${NC}"
}

# Function to configure HPA
configure_hpa() {
    local deployment=$1
    local min_replicas=${2:-2}
    local max_replicas=${3:-5}
    local cpu_threshold=${4:-70}
    
    echo -e "${BLUE}🎯 Configuring HPA for $deployment...${NC}"
    
    if ! $KUBECTL_CMD get deployment $deployment -n $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Deployment $deployment not found${NC}"
        return 1
    fi
    
    # Create HPA
    $KUBECTL_CMD autoscale deployment $deployment \
        --min=$min_replicas \
        --max=$max_replicas \
        --cpu-percent=$cpu_threshold \
        -n $NAMESPACE
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ HPA configured for $deployment${NC}"
        echo "   Min replicas: $min_replicas"
        echo "   Max replicas: $max_replicas"
        echo "   CPU threshold: $cpu_threshold%"
    else
        echo -e "${RED}❌ HPA configuration failed${NC}"
        return 1
    fi
}

# Function to remove HPA
remove_hpa() {
    local deployment=$1
    
    echo -e "${BLUE}🗑️  Removing HPA for $deployment...${NC}"
    
    if $KUBECTL_CMD delete hpa $deployment-hpa -n $NAMESPACE; then
        echo -e "${GREEN}✅ HPA removed for $deployment${NC}"
    else
        echo -e "${YELLOW}⚠️  HPA not found or already removed${NC}"
    fi
}

# Function for emergency scale down
emergency_scale_down() {
    echo -e "${RED}🚨 EMERGENCY SCALE DOWN${NC}"
    echo "This will scale all deployments to minimum replicas"
    echo ""
    
    read -p "Confirm emergency scale down? (type 'emergency'): " confirm
    
    if [ "$confirm" = "emergency" ]; then
        echo "Scaling down all deployments..."
        
        scale_deployment "backend" "1"
        scale_deployment "frontend" "1"
        # Keep PostgreSQL at 1 replica
        
        echo -e "${GREEN}✅ Emergency scale down completed${NC}"
    else
        echo "Emergency scale down cancelled"
    fi
}

# Function for performance scale up
performance_scale_up() {
    echo -e "${BLUE}🚀 PERFORMANCE SCALE UP${NC}"
    echo "This will scale deployments for high performance"
    echo ""
    
    # Check available resources
    local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    echo "Available memory: ${available_memory}GB"
    
    if (( $(echo "$available_memory < 4" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Limited memory available${NC}"
        echo "Consider conservative scaling or upgrading resources"
    fi
    
    read -p "Proceed with performance scaling? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "Scaling up for performance..."
        
        # Get current CPU cores
        local cpu_cores=$(nproc)
        
        if [ "$cpu_cores" -ge 4 ]; then
            # Scale up for multi-core systems
            scale_deployment "backend" "4"
            scale_deployment "frontend" "3"
        else
            # Conservative scaling for limited cores
            scale_deployment "backend" "2"
            scale_deployment "frontend" "2"
        fi
        
        echo -e "${GREEN}✅ Performance scaling completed${NC}"
    else
        echo "Performance scaling cancelled"
    fi
}

# Function to monitor scaling
monitor_scaling() {
    echo -e "${BLUE}👁️  Monitoring scaling activity...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}=== SCALING MONITOR - $(date) ===${NC}"
        echo ""
        
        show_scaling_status
        
        echo "Refreshing in 10 seconds..."
        sleep 10
    done
}

# Function to show scaling recommendations
show_recommendations() {
    echo -e "${BLUE}💡 Scaling Recommendations${NC}"
    echo ""
    
    # Check current resource usage
    if $KUBECTL_CMD top pods -n $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}📊 Current Resource Usage:${NC}"
        $KUBECTL_CMD top pods -n $NAMESPACE
        echo ""
        
        # Analyze CPU usage
        local high_cpu_pods=$($KUBECTL_CMD top pods -n $NAMESPACE --no-headers | awk '$3 ~ /[0-9]+m/ { gsub(/m/, "", $3); if ($3 > 100) print $1, $3"m" }')
        
        if [ -n "$high_cpu_pods" ]; then
            echo -e "${YELLOW}⚠️  High CPU usage detected:${NC}"
            echo "$high_cpu_pods"
            echo "   Recommendation: Consider scaling up"
            echo ""
        fi
        
        # Check memory usage
        local high_mem_pods=$($KUBECTL_CMD top pods -n $NAMESPACE --no-headers | awk '$4 ~ /[0-9]+Mi/ { gsub(/Mi/, "", $4); if ($4 > 200) print $1, $4"Mi" }')
        
        if [ -n "$high_mem_pods" ]; then
            echo -e "${YELLOW}⚠️  High memory usage detected:${NC}"
            echo "$high_mem_pods"
            echo "   Recommendation: Monitor for memory leaks or scale up"
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠️  Metrics server not available${NC}"
        echo "Install metrics-server for detailed recommendations"
        echo ""
    fi
    
    # System-level recommendations
    local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    local cpu_cores=$(nproc)
    
    echo -e "${GREEN}💻 System Resources:${NC}"
    echo "   Available Memory: ${available_memory}GB"
    echo "   CPU Cores: $cpu_cores"
    echo ""
    
    echo -e "${BLUE}📈 Scaling Recommendations:${NC}"
    
    if (( $(echo "$available_memory > 10" | bc -l) )); then
        echo "   ✅ Sufficient memory for scaling up"
        echo "   Safe to scale backend: 2-4 replicas"
        echo "   Safe to scale frontend: 2-3 replicas"
    elif (( $(echo "$available_memory > 4" | bc -l) )); then
        echo "   ⚠️  Moderate memory available"
        echo "   Conservative scaling: backend 2, frontend 2"
    else
        echo "   ❌ Limited memory available"
        echo "   Keep minimal replicas or upgrade resources"
    fi
    
    echo ""
    echo -e "${BLUE}🎯 Suggested Profiles:${NC}"
    echo "   Development: backend=1, frontend=1"
    echo "   Testing: backend=2, frontend=2"
    echo "   Production: backend=3-4, frontend=2-3"
}

# Function to apply scaling profile
apply_profile() {
    local profile=$1
    
    case $profile in
        minimal|dev)
            echo -e "${BLUE}📱 Applying minimal/development profile...${NC}"
            scale_deployment "backend" "1"
            scale_deployment "frontend" "1"
            ;;
        standard|test)
            echo -e "${BLUE}🧪 Applying standard/testing profile...${NC}"
            scale_deployment "backend" "2"
            scale_deployment "frontend" "2"
            ;;
        performance|prod)
            echo -e "${BLUE}🚀 Applying performance/production profile...${NC}"
            scale_deployment "backend" "3"
            scale_deployment "frontend" "2"
            ;;
        high-performance)
            echo -e "${BLUE}⚡ Applying high-performance profile...${NC}"
            scale_deployment "backend" "4"
            scale_deployment "frontend" "3"
            ;;
        *)
            echo -e "${RED}❌ Unknown profile: $profile${NC}"
            echo "Available profiles: minimal, standard, performance, high-performance"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Profile $profile applied${NC}"
}

# Main execution
main() {
    local action=${1:-status}
    local param1=${2:-}
    local param2=${3:-}
    local param3=${4:-}
    
    case $action in
        status)
            show_scaling_status
            ;;
        scale)
            if [ -n "$param1" ] && [ -n "$param2" ]; then
                scale_deployment "$param1" "$param2"
            else
                echo "Usage: $0 scale <deployment> <replicas>"
                echo "Example: $0 scale backend 3"
            fi
            ;;
        scale-all)
            scale_all "$param1" "$param2"
            ;;
        hpa)
            if [ "$param1" = "create" ]; then
                configure_hpa "$param2" "$param3" "${4:-}" "${5:-}"
            elif [ "$param1" = "delete" ]; then
                remove_hpa "$param2"
            else
                echo "Usage: $0 hpa create <deployment> [min] [max] [cpu-threshold]"
                echo "       $0 hpa delete <deployment>"
            fi
            ;;
        emergency)
            emergency_scale_down
            ;;
        performance)
            performance_scale_up
            ;;
        monitor)
            monitor_scaling
            ;;
        recommendations|recommend)
            show_recommendations
            ;;
        profile)
            if [ -n "$param1" ]; then
                apply_profile "$param1"
            else
                echo "Usage: $0 profile <profile-name>"
                echo "Profiles: minimal, standard, performance, high-performance"
            fi
            ;;
        help|--help|-h)
            echo "Usage: $0 <action> [parameters]"
            echo ""
            echo "Actions:"
            echo "  status                Show current scaling status"
            echo "  scale <deploy> <n>    Scale specific deployment to n replicas"
            echo "  scale-all [b] [f]     Scale backend to b, frontend to f replicas"
            echo "  hpa create <deploy>   Create HPA for deployment"
            echo "  hpa delete <deploy>   Delete HPA for deployment"
            echo "  emergency             Emergency scale down to minimal replicas"
            echo "  performance           Scale up for high performance"
            echo "  monitor               Monitor scaling activity (real-time)"
            echo "  recommendations       Show scaling recommendations"
            echo "  profile <name>        Apply scaling profile"
            echo "  help                  Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 status"
            echo "  $0 scale backend 3"
            echo "  $0 scale-all 2 2"
            echo "  $0 profile standard"
            echo "  $0 hpa create backend 2 5 70"
            echo ""
            echo "Profiles:"
            echo "  minimal        backend=1, frontend=1"
            echo "  standard       backend=2, frontend=2"
            echo "  performance    backend=3, frontend=2"
            echo "  high-performance backend=4, frontend=3"
            ;;
        *)
            echo -e "${RED}❌ Unknown action: $action${NC}"
            echo "Use '$0 help' for available actions"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
