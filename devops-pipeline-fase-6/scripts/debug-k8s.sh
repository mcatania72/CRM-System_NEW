#!/bin/bash

# FASE 6: Script di debug avanzato per Kubernetes
# Raccoglie informazioni dettagliate per troubleshooting

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
DEBUG_DIR="$HOME/crm-k8s-debug-$(date +%Y%m%d-%H%M%S)"

# Check kubectl
if ! kubectl version --client &>/dev/null; then
    KUBECTL_CMD="sudo k3s kubectl"
fi

echo -e "${BLUE}=== 🔍 FASE 6: Kubernetes Debug Analysis ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Debug Output: $DEBUG_DIR"
echo ""

# Create debug directory
mkdir -p "$DEBUG_DIR"

# Function to run command and save output
debug_command() {
    local title="$1"
    local command="$2"
    local output_file="$3"
    
    echo -e "${BLUE}🔍 $title${NC}"
    echo "# $title" > "$DEBUG_DIR/$output_file"
    echo "# Command: $command" >> "$DEBUG_DIR/$output_file"
    echo "# Timestamp: $(date)" >> "$DEBUG_DIR/$output_file"
    echo "" >> "$DEBUG_DIR/$output_file"
    
    if eval "$command" >> "$DEBUG_DIR/$output_file" 2>&1; then
        echo -e "${GREEN}✅ $title - Data collected${NC}"
    else
        echo -e "${YELLOW}⚠️  $title - Some data may be missing${NC}"
    fi
}

# Cluster Information
collect_cluster_info() {
    echo -e "${PURPLE}=== 🌐 CLUSTER INFORMATION ===${NC}"
    
    debug_command "Cluster Info" \
        "$KUBECTL_CMD cluster-info" \
        "01-cluster-info.txt"
    
    debug_command "Cluster Version" \
        "$KUBECTL_CMD version" \
        "02-cluster-version.txt"
    
    debug_command "Node Information" \
        "$KUBECTL_CMD get nodes -o wide" \
        "03-nodes.txt"
    
    debug_command "Node Details" \
        "$KUBECTL_CMD describe nodes" \
        "04-nodes-detailed.txt"
    
    debug_command "System Pods" \
        "$KUBECTL_CMD get pods -n kube-system -o wide" \
        "05-system-pods.txt"
}

# Storage Information
collect_storage_info() {
    echo -e "${PURPLE}=== 💾 STORAGE INFORMATION ===${NC}"
    
    debug_command "Storage Classes" \
        "$KUBECTL_CMD get storageclass -o wide" \
        "10-storage-classes.txt"
    
    debug_command "Persistent Volumes" \
        "$KUBECTL_CMD get pv -o wide" \
        "11-persistent-volumes.txt"
    
    debug_command "PV Details" \
        "$KUBECTL_CMD describe pv" \
        "12-pv-details.txt"
    
    debug_command "Persistent Volume Claims" \
        "$KUBECTL_CMD get pvc -A -o wide" \
        "13-pvc-all-namespaces.txt"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        debug_command "CRM PVC Details" \
            "$KUBECTL_CMD describe pvc -n $NAMESPACE" \
            "14-crm-pvc-details.txt"
    fi
}

# Namespace and Resource Information
collect_namespace_info() {
    echo -e "${PURPLE}=== 📁 NAMESPACE INFORMATION ===${NC}"
    
    debug_command "All Namespaces" \
        "$KUBECTL_CMD get namespaces -o wide" \
        "20-namespaces.txt"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        debug_command "CRM Namespace Details" \
            "$KUBECTL_CMD describe namespace $NAMESPACE" \
            "21-crm-namespace-details.txt"
        
        debug_command "CRM All Resources" \
            "$KUBECTL_CMD get all -n $NAMESPACE -o wide" \
            "22-crm-all-resources.txt"
        
        debug_command "CRM Resource Details" \
            "$KUBECTL_CMD describe all -n $NAMESPACE" \
            "23-crm-resource-details.txt"
        
        debug_command "CRM Secrets" \
            "$KUBECTL_CMD get secrets -n $NAMESPACE -o wide" \
            "24-crm-secrets.txt"
        
        debug_command "CRM ConfigMaps" \
            "$KUBECTL_CMD get configmaps -n $NAMESPACE -o wide" \
            "25-crm-configmaps.txt"
    else
        echo "Namespace $NAMESPACE does not exist" > "$DEBUG_DIR/21-namespace-missing.txt"
    fi
}

# Pod Information
collect_pod_info() {
    echo -e "${PURPLE}=== 🏃 POD INFORMATION ===${NC}"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        debug_command "CRM Pods Status" \
            "$KUBECTL_CMD get pods -n $NAMESPACE -o wide" \
            "30-crm-pods.txt"
        
        debug_command "CRM Pod Details" \
            "$KUBECTL_CMD describe pods -n $NAMESPACE" \
            "31-crm-pod-details.txt"
        
        # Individual pod logs
        local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$pods" ]; then
            echo "$pods" | tr ' ' '\n' | while read pod; do
                if [ -n "$pod" ]; then
                    debug_command "Pod Logs: $pod" \
                        "$KUBECTL_CMD logs $pod -n $NAMESPACE --all-containers=true --previous=false" \
                        "32-logs-$pod.txt"
                    
                    # Previous logs if pod has restarted
                    if $KUBECTL_CMD logs $pod -n $NAMESPACE --previous &>/dev/null; then
                        debug_command "Previous Pod Logs: $pod" \
                            "$KUBECTL_CMD logs $pod -n $NAMESPACE --all-containers=true --previous=true" \
                            "33-previous-logs-$pod.txt"
                    fi
                fi
            done
        fi
    fi
}

# Service and Network Information
collect_network_info() {
    echo -e "${PURPLE}=== 🔗 NETWORK INFORMATION ===${NC}"
    
    debug_command "All Services" \
        "$KUBECTL_CMD get svc -A -o wide" \
        "40-all-services.txt"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        debug_command "CRM Services" \
            "$KUBECTL_CMD get svc -n $NAMESPACE -o wide" \
            "41-crm-services.txt"
        
        debug_command "CRM Service Details" \
            "$KUBECTL_CMD describe svc -n $NAMESPACE" \
            "42-crm-service-details.txt"
        
        debug_command "CRM Endpoints" \
            "$KUBECTL_CMD get endpoints -n $NAMESPACE -o wide" \
            "43-crm-endpoints.txt"
        
        debug_command "CRM Ingress" \
            "$KUBECTL_CMD get ingress -n $NAMESPACE -o wide" \
            "44-crm-ingress.txt"
    fi
    
    debug_command "LoadBalancer Services" \
        "$KUBECTL_CMD get svc -A | grep LoadBalancer" \
        "45-loadbalancer-services.txt"
    
    debug_command "Network Policies" \
        "$KUBECTL_CMD get networkpolicy -A -o wide" \
        "46-network-policies.txt"
}

# Events and Monitoring
collect_events_monitoring() {
    echo -e "${PURPLE}=== 📊 EVENTS AND MONITORING ===${NC}"
    
    debug_command "Cluster Events" \
        "$KUBECTL_CMD get events -A --sort-by='.lastTimestamp'" \
        "50-cluster-events.txt"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        debug_command "CRM Events" \
            "$KUBECTL_CMD get events -n $NAMESPACE --sort-by='.lastTimestamp'" \
            "51-crm-events.txt"
    fi
    
    # Resource usage if metrics-server is available
    if $KUBECTL_CMD top nodes &>/dev/null; then
        debug_command "Node Resource Usage" \
            "$KUBECTL_CMD top nodes" \
            "52-node-resources.txt"
        
        debug_command "Pod Resource Usage" \
            "$KUBECTL_CMD top pods -A" \
            "53-pod-resources.txt"
        
        if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
            debug_command "CRM Pod Resources" \
                "$KUBECTL_CMD top pods -n $NAMESPACE" \
                "54-crm-pod-resources.txt"
        fi
    else
        echo "Metrics server not available" > "$DEBUG_DIR/52-no-metrics.txt"
    fi
}

# System Information
collect_system_info() {
    echo -e "${PURPLE}=== 🖥️  SYSTEM INFORMATION ===${NC}"
    
    debug_command "System Info" \
        "uname -a && cat /etc/os-release" \
        "60-system-info.txt"
    
    debug_command "Memory Info" \
        "free -h" \
        "61-memory-info.txt"
    
    debug_command "Disk Usage" \
        "df -h" \
        "62-disk-usage.txt"
    
    debug_command "Docker Info" \
        "docker info 2>/dev/null || echo 'Docker not available'" \
        "63-docker-info.txt"
    
    debug_command "Docker Images" \
        "docker images 2>/dev/null || echo 'Docker not available'" \
        "64-docker-images.txt"
    
    debug_command "Process List" \
        "ps aux | head -20" \
        "65-processes.txt"
    
    debug_command "Network Interfaces" \
        "ip addr show" \
        "66-network-interfaces.txt"
    
    debug_command "Port Usage" \
        "netstat -tlnp 2>/dev/null || ss -tlnp" \
        "67-port-usage.txt"
}

# Application Specific Debug
collect_app_debug() {
    echo -e "${PURPLE}=== 🎯 APPLICATION DEBUG ===${NC}"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        # Test internal connectivity
        local backend_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$backend_pod" ]; then
            debug_command "Backend Environment" \
                "$KUBECTL_CMD exec $backend_pod -n $NAMESPACE -- env | sort" \
                "70-backend-env.txt"
            
            debug_command "Backend Network Test" \
                "$KUBECTL_CMD exec $backend_pod -n $NAMESPACE -- nc -zv postgres-service 5432" \
                "71-backend-network-test.txt"
            
            debug_command "Backend DNS Resolution" \
                "$KUBECTL_CMD exec $backend_pod -n $NAMESPACE -- nslookup postgres-service" \
                "72-backend-dns.txt"
        fi
        
        # PostgreSQL specific debug
        local postgres_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$postgres_pod" ]; then
            debug_command "PostgreSQL Status" \
                "$KUBECTL_CMD exec $postgres_pod -n $NAMESPACE -- psql -U postgres -d crm -c 'SELECT version();'" \
                "73-postgres-version.txt"
            
            debug_command "PostgreSQL Connections" \
                "$KUBECTL_CMD exec $postgres_pod -n $NAMESPACE -- psql -U postgres -d crm -c 'SELECT count(*) FROM pg_stat_activity;'" \
                "74-postgres-connections.txt"
            
            debug_command "PostgreSQL Tables" \
                "$KUBECTL_CMD exec $postgres_pod -n $NAMESPACE -- psql -U postgres -d crm -c '\dt'" \
                "75-postgres-tables.txt"
        fi
    fi
}

# External Connectivity Test
test_external_connectivity() {
    echo -e "${PURPLE}=== 🌐 EXTERNAL CONNECTIVITY ===${NC}"
    
    # Get LoadBalancer IP
    local lb_ip=$($KUBECTL_CMD get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "192.168.1.29")
    
    debug_command "LoadBalancer Test" \
        "ping -c 3 $lb_ip" \
        "80-loadbalancer-ping.txt"
    
    if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        # Get NodePort services
        local frontend_port=$($KUBECTL_CMD get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        local backend_port=$($KUBECTL_CMD get svc backend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        
        if [ -n "$frontend_port" ]; then
            debug_command "Frontend Connectivity Test" \
                "curl -I --connect-timeout 10 http://$lb_ip:$frontend_port" \
                "81-frontend-connectivity.txt"
        fi
        
        if [ -n "$backend_port" ]; then
            debug_command "Backend API Test" \
                "curl -I --connect-timeout 10 http://$lb_ip:$backend_port/api/health" \
                "82-backend-api-test.txt"
        fi
    fi
}

# Generate summary report
generate_summary() {
    echo -e "${BLUE}📋 Generating debug summary...${NC}"
    
    cat > "$DEBUG_DIR/00-SUMMARY.md" << EOF
# Kubernetes Debug Report

**Generated**: $(date)
**Namespace**: $NAMESPACE
**Kubectl Command**: $KUBECTL_CMD

## Quick Analysis

### Cluster Status
- Cluster Info: See 01-cluster-info.txt
- Nodes: See 03-nodes.txt
- System Pods: See 05-system-pods.txt

### CRM Application Status
- Namespace Exists: $(if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then echo "YES"; else echo "NO"; fi)
- Pods Running: $(if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then $KUBECTL_CMD get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c Running || echo "0"; else echo "N/A"; fi)
- Services Available: $(if $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then $KUBECTL_CMD get svc -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0"; else echo "N/A"; fi)

### Storage Status
- PVC Status: See 13-pvc-all-namespaces.txt
- Storage Classes: See 10-storage-classes.txt

### Common Issues to Check
1. **Pod Issues**: Check 31-crm-pod-details.txt for pod status
2. **Storage Issues**: Check 14-crm-pvc-details.txt for PVC problems
3. **Network Issues**: Check 42-crm-service-details.txt for service problems
4. **Application Logs**: Check 32-logs-*.txt files for application errors
5. **Events**: Check 51-crm-events.txt for recent events

### Files Generated
EOF

    # List all generated files
    ls -la "$DEBUG_DIR" | grep -v "^total" | awk '{print "- " $9}' >> "$DEBUG_DIR/00-SUMMARY.md"
    
    echo "" >> "$DEBUG_DIR/00-SUMMARY.md"
    echo "### Recommended Next Steps" >> "$DEBUG_DIR/00-SUMMARY.md"
    
    if ! $KUBECTL_CMD get namespace $NAMESPACE &>/dev/null; then
        echo "- Namespace does not exist. Run: ./deploy-k8s.sh start" >> "$DEBUG_DIR/00-SUMMARY.md"
    else
        local pod_count=$($KUBECTL_CMD get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$pod_count" -eq 0 ]; then
            echo "- No pods running. Check pod logs and events." >> "$DEBUG_DIR/00-SUMMARY.md"
            echo "- Try: kubectl describe pods -n $NAMESPACE" >> "$DEBUG_DIR/00-SUMMARY.md"
        elif [ "$pod_count" -lt 3 ]; then
            echo "- Some pods may be missing. Expected: 3+ pods (postgres, backend, frontend)" >> "$DEBUG_DIR/00-SUMMARY.md"
        else
            echo "- All pods appear to be running. Check application logs for errors." >> "$DEBUG_DIR/00-SUMMARY.md"
        fi
    fi
    
    echo -e "${GREEN}✅ Summary generated: $DEBUG_DIR/00-SUMMARY.md${NC}"
}

# Main execution
main() {
    local debug_type=${1:-all}
    
    case $debug_type in
        cluster)
            collect_cluster_info
            ;;
        storage)
            collect_storage_info
            ;;
        pods)
            collect_pod_info
            ;;
        network)
            collect_network_info
            ;;
        app|application)
            collect_app_debug
            ;;
        connectivity)
            test_external_connectivity
            ;;
        quick)
            collect_cluster_info
            collect_namespace_info
            collect_pod_info
            ;;
        all|"")
            collect_cluster_info
            collect_storage_info
            collect_namespace_info
            collect_pod_info
            collect_network_info
            collect_events_monitoring
            collect_system_info
            collect_app_debug
            test_external_connectivity
            ;;
        help|--help|-h)
            echo "Usage: $0 [debug_type]"
            echo ""
            echo "Debug Types:"
            echo "  all          Collect all debug information (default)"
            echo "  quick        Essential information only"
            echo "  cluster      Cluster and node information"
            echo "  storage      Storage and PV information"
            echo "  pods         Pod status and logs"
            echo "  network      Service and network information"
            echo "  app          Application-specific debug"
            echo "  connectivity External connectivity tests"
            echo "  help         Show this help"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown debug type: $debug_type${NC}"
            echo "Use '$0 help' for available options"
            exit 1
            ;;
    esac
    
    # Always generate summary (except for help)
    if [ "$debug_type" != "help" ]; then
        generate_summary
        
        echo ""
        echo -e "${GREEN}✅ Debug information collected successfully!${NC}"
        echo -e "${BLUE}📁 Debug directory: $DEBUG_DIR${NC}"
        echo -e "${BLUE}📋 Summary report: $DEBUG_DIR/00-SUMMARY.md${NC}"
        echo ""
        echo -e "${YELLOW}💡 To view the summary:${NC}"
        echo "   cat $DEBUG_DIR/00-SUMMARY.md"
        echo ""
        echo -e "${YELLOW}💡 To share debug info:${NC}"
        echo "   tar -czf crm-debug.tar.gz -C $(dirname $DEBUG_DIR) $(basename $DEBUG_DIR)"
        echo ""
    fi
}

# Execute main function
main "$@"
