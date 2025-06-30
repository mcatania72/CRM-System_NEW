#!/bin/bash

# FASE 6: Cleanup completo del namespace Kubernetes
# Rimuove tutto il deployment CRM dal cluster K8s

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

echo -e "${BLUE}=== 🧹 FASE 6: Kubernetes Cleanup ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Kubectl: $KUBECTL_CMD"
echo ""

# Function to confirm action
confirm_cleanup() {
    echo -e "${YELLOW}⚠️  WARNING: This will completely remove the CRM deployment!${NC}"
    echo ""
    echo "This will delete:"
    echo "  - All pods, deployments, services"
    echo "  - Persistent Volume Claims (DATA LOSS!)"
    echo "  - Secrets and ConfigMaps"
    echo "  - The entire $NAMESPACE namespace"
    echo ""
    
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo -e "${GREEN}✅ Cleanup cancelled${NC}"
        exit 0
    fi
}

# Function to backup data before cleanup
backup_data() {
    echo -e "${BLUE}💾 Creating backup before cleanup...${NC}"
    
    # Create backup directory
    BACKUP_DIR="$HOME/crm-k8s-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Export all resources
    echo "Exporting Kubernetes resources..."
    $KUBECTL_CMD get all -n $NAMESPACE -o yaml > "$BACKUP_DIR/all-resources.yaml" 2>/dev/null || true
    $KUBECTL_CMD get pvc -n $NAMESPACE -o yaml > "$BACKUP_DIR/pvc-resources.yaml" 2>/dev/null || true
    $KUBECTL_CMD get secrets -n $NAMESPACE -o yaml > "$BACKUP_DIR/secrets.yaml" 2>/dev/null || true
    $KUBECTL_CMD get configmaps -n $NAMESPACE -o yaml > "$BACKUP_DIR/configmaps.yaml" 2>/dev/null || true
    
    # Database backup if possible
    echo "Attempting database backup..."
    POSTGRES_POD=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ]; then
        echo "Creating PostgreSQL database dump..."
        $KUBECTL_CMD exec $POSTGRES_POD -n $NAMESPACE -- pg_dump -U postgres -d crm > "$BACKUP_DIR/database-dump.sql" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Database backup failed (pod may not be ready)${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  No PostgreSQL pod found for backup${NC}"
    fi
    
    echo -e "${GREEN}✅ Backup created in: $BACKUP_DIR${NC}"
}

# Function to scale down deployments gracefully
scale_down_deployments() {
    echo -e "${BLUE}📉 Scaling down deployments gracefully...${NC}"
    
    # Scale down to 0 replicas
    $KUBECTL_CMD scale deployment --all --replicas=0 -n $NAMESPACE 2>/dev/null || true
    
    # Wait for pods to terminate
    echo "Waiting for pods to terminate..."
    $KUBECTL_CMD wait --for=delete pod --all -n $NAMESPACE --timeout=300s 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Some pods may still be terminating${NC}"
    }
    
    echo -e "${GREEN}✅ Deployments scaled down${NC}"
}

# Function to delete resources in order
delete_resources() {
    echo -e "${BLUE}🗑️  Deleting Kubernetes resources...${NC}"
    
    # Delete HPA first
    echo "Deleting Horizontal Pod Autoscalers..."
    $KUBECTL_CMD delete hpa --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete Pod Disruption Budgets
    echo "Deleting Pod Disruption Budgets..."
    $KUBECTL_CMD delete pdb --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete Ingress
    echo "Deleting Ingress resources..."
    $KUBECTL_CMD delete ingress --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete Services
    echo "Deleting Services..."
    $KUBECTL_CMD delete svc --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete Deployments
    echo "Deleting Deployments..."
    $KUBECTL_CMD delete deployment --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete ConfigMaps
    echo "Deleting ConfigMaps..."
    $KUBECTL_CMD delete configmap --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete Secrets
    echo "Deleting Secrets..."
    $KUBECTL_CMD delete secret --all -n $NAMESPACE 2>/dev/null || true
    
    echo -e "${GREEN}✅ Resources deleted${NC}"
}

# Function to delete persistent volumes
delete_storage() {
    echo -e "${BLUE}💾 Deleting storage resources...${NC}"
    
    # List PVCs before deletion
    echo "Current Persistent Volume Claims:"
    $KUBECTL_CMD get pvc -n $NAMESPACE 2>/dev/null || echo "No PVCs found"
    
    # Delete PVCs (this will cause data loss!)
    echo -e "${RED}⚠️  Deleting PVCs (DATA LOSS!)...${NC}"
    $KUBECTL_CMD delete pvc --all -n $NAMESPACE 2>/dev/null || true
    
    # Wait for PV cleanup
    echo "Waiting for Persistent Volumes cleanup..."
    sleep 10
    
    # Check for orphaned PVs
    echo "Checking for orphaned Persistent Volumes..."
    ORPHANED_PVS=$($KUBECTL_CMD get pv | grep "crm-system" | awk '{print $1}' 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED_PVS" ]; then
        echo "Found orphaned PVs, cleaning up..."
        echo "$ORPHANED_PVS" | while read pv; do
            $KUBECTL_CMD delete pv "$pv" 2>/dev/null || true
        done
    fi
    
    echo -e "${GREEN}✅ Storage resources deleted${NC}"
}

# Function to delete namespace
delete_namespace() {
    echo -e "${BLUE}📁 Deleting namespace...${NC}"
    
    # Delete the namespace (this will cascade delete everything)
    $KUBECTL_CMD delete namespace $NAMESPACE 2>/dev/null || true
    
    # Wait for namespace deletion
    echo "Waiting for namespace deletion to complete..."
    while $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; do
        echo "Namespace still exists, waiting..."
        sleep 5
    done
    
    echo -e "${GREEN}✅ Namespace deleted${NC}"
}

# Function to clean up Docker images
cleanup_docker_images() {
    echo -e "${BLUE}🐳 Cleaning up Docker images...${NC}"
    
    # List CRM images
    echo "Current CRM Docker images:"
    docker images | grep -E "crm-|postgres" | head -10 2>/dev/null || echo "No CRM images found"
    
    read -p "Remove CRM Docker images? (y/n): " remove_images
    
    if [ "$remove_images" = "y" ] || [ "$remove_images" = "Y" ]; then
        # Remove CRM images
        docker images | grep "crm-" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
        
        # Clean up dangling images
        docker image prune -f 2>/dev/null || true
        
        echo -e "${GREEN}✅ Docker images cleaned up${NC}"
    else
        echo "Docker images cleanup skipped"
    fi
}

# Function to verify cleanup
verify_cleanup() {
    echo -e "${BLUE}🔍 Verifying cleanup...${NC}"
    
    # Check namespace
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE still exists${NC}"
    else
        echo -e "${GREEN}✅ Namespace $NAMESPACE removed${NC}"
    fi
    
    # Check for orphaned resources
    echo "Checking for orphaned resources..."
    
    # Check PVs
    ORPHANED_PVS=$($KUBECTL_CMD get pv | grep -c "crm-system" 2>/dev/null || echo "0")
    if [ "$ORPHANED_PVS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Found $ORPHANED_PVS orphaned Persistent Volumes${NC}"
        $KUBECTL_CMD get pv | grep "crm-system" || true
    else
        echo -e "${GREEN}✅ No orphaned Persistent Volumes${NC}"
    fi
    
    # Check storage classes
    echo "Storage classes still available:"
    $KUBECTL_CMD get storageclass
    
    echo -e "${GREEN}✅ Cleanup verification completed${NC}"
}

# Function to show post-cleanup information
show_post_cleanup_info() {
    echo ""
    echo -e "${PURPLE}=== 📋 POST-CLEANUP INFORMATION ===${NC}"
    echo ""
    echo -e "${GREEN}🎯 Cleanup Summary:${NC}"
    echo "   - Namespace '$NAMESPACE' deleted"
    echo "   - All CRM pods, services, deployments removed"
    echo "   - Persistent volumes and data deleted"
    echo "   - Secrets and configuration removed"
    echo ""
    
    if [ -n "${BACKUP_DIR:-}" ]; then
        echo -e "${GREEN}💾 Backup Location:${NC}"
        echo "   $BACKUP_DIR"
        echo ""
        echo -e "${BLUE}To restore from backup:${NC}"
        echo "   1. kubectl create namespace $NAMESPACE"
        echo "   2. kubectl apply -f $BACKUP_DIR/secrets.yaml"
        echo "   3. kubectl apply -f $BACKUP_DIR/configmaps.yaml"
        echo "   4. kubectl apply -f $BACKUP_DIR/pvc-resources.yaml"
        echo "   5. kubectl apply -f $BACKUP_DIR/all-resources.yaml"
        echo ""
    fi
    
    echo -e "${GREEN}🚀 To redeploy CRM:${NC}"
    echo "   ./deploy-k8s.sh start"
    echo ""
    
    echo -e "${GREEN}🔍 To verify cluster state:${NC}"
    echo "   kubectl get namespaces"
    echo "   kubectl get pv"
    echo "   kubectl get storageclass"
    echo ""
}

# Main execution
main() {
    local action=${1:-interactive}
    
    case $action in
        --force)
            echo -e "${RED}🚨 FORCE CLEANUP MODE${NC}"
            backup_data
            scale_down_deployments
            delete_resources
            delete_storage
            delete_namespace
            cleanup_docker_images
            verify_cleanup
            show_post_cleanup_info
            ;;
        --no-backup)
            echo -e "${YELLOW}⚠️  CLEANUP WITHOUT BACKUP${NC}"
            confirm_cleanup
            scale_down_deployments
            delete_resources
            delete_storage
            delete_namespace
            verify_cleanup
            show_post_cleanup_info
            ;;
        --namespace-only)
            echo -e "${BLUE}📁 NAMESPACE CLEANUP ONLY${NC}"
            confirm_cleanup
            delete_namespace
            verify_cleanup
            ;;
        --help)
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  (no option)    Interactive cleanup with backup"
            echo "  --force        Force cleanup with backup (no confirmation)"
            echo "  --no-backup    Cleanup without backup"
            echo "  --namespace-only  Delete only namespace (fastest)"
            echo "  --help         Show this help"
            echo ""
            exit 0
            ;;
        *)
            # Interactive mode (default)
            confirm_cleanup
            backup_data
            scale_down_deployments
            delete_resources
            delete_storage
            delete_namespace
            cleanup_docker_images
            verify_cleanup
            show_post_cleanup_info
            ;;
    esac
    
    echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
}

# Execute main function
main "$@"
