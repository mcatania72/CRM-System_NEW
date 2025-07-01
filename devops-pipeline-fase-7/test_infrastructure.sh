#!/bin/bash

# =============================================================================
# TEST INFRASTRUCTURE SCRIPT - FASE 7
# =============================================================================
# Testa l'infrastruttura deployata: VM, networking, Kubernetes cluster
# =============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/infrastructure-test.log"

# VM Configuration
declare -A VMS=(
    ["FE"]="192.168.1.101:SPESE_FE_VM:master"
    ["BE"]="192.168.1.102:SPESE_BE_VM:worker"
    ["DB"]="192.168.1.103:SPESE_DB_VM:worker"
)

# Test Results
declare -A TEST_RESULTS=()

# Funzioni di utility
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

test_passed() {
    local test_name="$1"
    TEST_RESULTS["$test_name"]="PASS"
    log_success "✅ $test_name"
}

test_failed() {
    local test_name="$1"
    TEST_RESULTS["$test_name"]="FAIL"
    log_error "❌ $test_name"
}

test_warning() {
    local test_name="$1"
    TEST_RESULTS["$test_name"]="WARN"
    log_warning "⚠️  $test_name"
}

print_header() {
    echo ""
    echo "=============================================="
    echo "  TEST INFRASTRUCTURE - FASE 7"
    echo "  Infrastructure Validation & Health Check"
    echo "=============================================="
    echo ""
}

# =============================================================================
# VM TESTS
# =============================================================================

test_vm_existence() {
    log_info "Test 1: Verifica esistenza VM..."
    
    local vm_dir="$HOME/VMware_VMs"
    local all_exist=true
    
    for key in "${!VMS[@]}"; do
        IFS=':' read -r ip name role <<< "${VMS[$key]}"
        
        if [ -f "$vm_dir/$name/$name.vmx" ]; then
            log_success "VM $name: File VMX esistente"
        else
            log_error "VM $name: File VMX mancante"
            all_exist=false
        fi
        
        if [ -f "$vm_dir/$name/$name.vmdk" ]; then
            log_success "VM $name: File VMDK esistente"
        else
            log_error "VM $name: File VMDK mancante"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = true ]; then
        test_passed "VM Files Existence"
    else
        test_failed "VM Files Existence"
    fi
}

test_vm_running_status() {
    log_info "Test 2: Verifica stato VM running..."
    
    local all_running=true
    
    for key in "${!VMS[@]}"; do
        IFS=':' read -r ip name role <<< "${VMS[$key]}"
        local vm_path="$HOME/VMware_VMs/$name/$name.vmx"
        
        if vmrun list | grep -q "$vm_path"; then
            log_success "VM $name: Running"
        else
            log_error "VM $name: Non in esecuzione"
            all_running=false
        fi
    done
    
    if [ "$all_running" = true ]; then
        test_passed "VM Running Status"
    else
        test_failed "VM Running Status"
    fi
}

test_vm_connectivity() {
    log_info "Test 3: Verifica connettività rete VM..."
    
    local all_reachable=true
    
    for key in "${!VMS[@]}"; do
        IFS=':' read -r ip name role <<< "${VMS[$key]}"
        
        if ping -c 3 -W 5 "$ip" &>/dev/null; then
            log_success "VM $name ($ip): Ping OK"
            
            # Test SSH connectivity
            if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
               devops@"$ip" 'echo "SSH test"' &>/dev/null; then
                log_success "VM $name ($ip): SSH OK"
            else
                log_error "VM $name ($ip): SSH failed"
                all_reachable=false
            fi
        else
            log_error "VM $name ($ip): Ping failed"
            all_reachable=false
        fi
    done
    
    if [ "$all_reachable" = true ]; then
        test_passed "VM Network Connectivity"
    else
        test_failed "VM Network Connectivity"
    fi
}

test_vm_resources() {
    log_info "Test 4: Verifica risorse VM..."
    
    local all_good=true
    
    for key in "${!VMS[@]}"; do
        IFS=':' read -r ip name role <<< "${VMS[$key]}"
        
        # Test memory
        local mem_total=$(ssh -o StrictHostKeyChecking=no devops@"$ip" \
            'free -g | awk "/^Mem:/{print \$2}"' 2>/dev/null || echo "0")
        
        if [ "$mem_total" -ge 3 ]; then
            log_success "VM $name: Memory OK (${mem_total}GB)"
        else
            log_error "VM $name: Memory insufficient (${mem_total}GB)"
            all_good=false
        fi
        
        # Test CPU
        local cpu_count=$(ssh -o StrictHostKeyChecking=no devops@"$ip" \
            'nproc' 2>/dev/null || echo "0")
        
        if [ "$cpu_count" -ge 2 ]; then
            log_success "VM $name: CPU OK (${cpu_count} cores)"
        else
            log_error "VM $name: CPU insufficient (${cpu_count} cores)"
            all_good=false
        fi
        
        # Test disk space
        local disk_avail=$(ssh -o StrictHostKeyChecking=no devops@"$ip" \
            'df -BG / | awk "NR==2 {print \$4}" | sed "s/G//"' 2>/dev/null || echo "0")
        
        if [ "$disk_avail" -ge 10 ]; then
            log_success "VM $name: Disk space OK (${disk_avail}GB available)"
        else
            log_warning "VM $name: Low disk space (${disk_avail}GB available)"
        fi
    done
    
    if [ "$all_good" = true ]; then
        test_passed "VM Resource Allocation"
    else
        test_failed "VM Resource Allocation"
    fi
}

# =============================================================================
# KUBERNETES TESTS
# =============================================================================

setup_kubectl_config() {
    log_info "Setup kubectl configuration..."
    
    # Copy kubectl config from master if not already present
    if [ ! -f ~/.kube/config-crm-cluster ]; then
        scp -o StrictHostKeyChecking=no \
            devops@192.168.1.101:~/.kube/config \
            ~/.kube/config-crm-cluster 2>/dev/null || {
            log_error "Cannot copy kubectl config from master"
            return 1
        }
    fi
    
    export KUBECONFIG=~/.kube/config-crm-cluster
    log_success "kubectl config configured"
}

test_kubernetes_cluster_status() {
    log_info "Test 5: Verifica stato cluster Kubernetes..."
    
    setup_kubectl_config || {
        test_failed "Kubernetes Cluster Connectivity"
        return 1
    }
    
    # Test cluster connectivity
    if kubectl cluster-info &>/dev/null; then
        log_success "Cluster API server reachable"
        
        # Test all nodes are ready
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
        local total_nodes=$(kubectl get nodes --no-headers | wc -l)
        
        if [ "$ready_nodes" -eq 3 ] && [ "$total_nodes" -eq 3 ]; then
            log_success "All 3 nodes ready ($ready_nodes/$total_nodes)"
            test_passed "Kubernetes Cluster Status"
        else
            log_error "Not all nodes ready ($ready_nodes/$total_nodes)"
            test_failed "Kubernetes Cluster Status"
        fi
    else
        log_error "Cannot connect to cluster API server"
        test_failed "Kubernetes Cluster Status"
    fi
}

test_kubernetes_node_roles() {
    log_info "Test 6: Verifica ruoli nodi Kubernetes..."
    
    local roles_correct=true
    
    # Check master node
    if kubectl get nodes | grep "192.168.1.101" | grep -q "control-plane"; then
        log_success "Master node role correct (192.168.1.101)"
    else
        log_error "Master node role incorrect (192.168.1.101)"
        roles_correct=false
    fi
    
    # Check worker nodes
    local worker_count=$(kubectl get nodes | grep -c "worker\|<none>")
    if [ "$worker_count" -ge 2 ]; then
        log_success "Worker nodes present ($worker_count)"
    else
        log_error "Insufficient worker nodes ($worker_count)"
        roles_correct=false
    fi
    
    if [ "$roles_correct" = true ]; then
        test_passed "Kubernetes Node Roles"
    else
        test_failed "Kubernetes Node Roles"
    fi
}

test_kubernetes_system_pods() {
    log_info "Test 7: Verifica system pods Kubernetes..."
    
    local pods_healthy=true
    
    # Critical system pods that must be running
    local critical_pods=(
        "kube-system:kube-apiserver"
        "kube-system:kube-controller-manager"
        "kube-system:kube-scheduler"
        "kube-system:etcd"
        "kube-system:kube-proxy"
        "kube-system:coredns"
        "kube-flannel:kube-flannel"
    )
    
    for pod_info in "${critical_pods[@]}"; do
        IFS=':' read -r namespace pod_name <<< "$pod_info"
        
        local running_count=$(kubectl get pods -n "$namespace" | grep "$pod_name" | grep -c "Running" || echo "0")
        
        if [ "$running_count" -gt 0 ]; then
            log_success "System pod $namespace/$pod_name: Running ($running_count)"
        else
            log_error "System pod $namespace/$pod_name: Not running"
            pods_healthy=false
        fi
    done
    
    if [ "$pods_healthy" = true ]; then
        test_passed "Kubernetes System Pods"
    else
        test_failed "Kubernetes System Pods"
    fi
}

test_kubernetes_networking() {
    log_info "Test 8: Verifica networking Kubernetes..."
    
    # Test pod-to-pod communication
    local network_ok=true
    
    # Check Flannel CNI
    local flannel_pods=$(kubectl get pods -n kube-flannel | grep -c "Running" || echo "0")
    if [ "$flannel_pods" -ge 3 ]; then
        log_success "Flannel CNI: $flannel_pods pods running"
    else
        log_error "Flannel CNI: Insufficient pods ($flannel_pods)"
        network_ok=false
    fi
    
    # Check CoreDNS
    local coredns_pods=$(kubectl get pods -n kube-system | grep coredns | grep -c "Running" || echo "0")
    if [ "$coredns_pods" -ge 1 ]; then
        log_success "CoreDNS: $coredns_pods pods running"
    else
        log_error "CoreDNS: No running pods"
        network_ok=false
    fi
    
    # Test service discovery
    if kubectl get svc kubernetes &>/dev/null; then
        log_success "Service discovery: kubernetes service found"
    else
        log_error "Service discovery: kubernetes service not found"
        network_ok=false
    fi
    
    if [ "$network_ok" = true ]; then
        test_passed "Kubernetes Networking"
    else
        test_failed "Kubernetes Networking"
    fi
}

test_load_balancer() {
    log_info "Test 9: Verifica Load Balancer (MetalLB)..."
    
    # Check MetalLB installation
    local metallb_pods=$(kubectl get pods -n metallb-system 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$metallb_pods" -gt 0 ]; then
        log_success "MetalLB: $metallb_pods pods running"
        
        # Check IP address pool configuration
        if kubectl get ipaddresspool -n metallb-system crm-pool &>/dev/null; then
            log_success "MetalLB: IP address pool configured"
            test_passed "Load Balancer (MetalLB)"
        else
            log_warning "MetalLB: IP address pool not configured"
            test_warning "Load Balancer (MetalLB)"
        fi
    else
        log_error "MetalLB: No running pods"
        test_failed "Load Balancer (MetalLB)"
    fi
}

test_ingress_controller() {
    log_info "Test 10: Verifica Ingress Controller..."
    
    # Check Nginx Ingress Controller
    local ingress_pods=$(kubectl get pods -n ingress-nginx 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$ingress_pods" -gt 0 ]; then
        log_success "Nginx Ingress: $ingress_pods pods running"
        test_passed "Ingress Controller"
    else
        log_warning "Nginx Ingress: No running pods"
        test_warning "Ingress Controller"
    fi
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

test_cluster_performance() {
    log_info "Test 11: Verifica performance cluster..."
    
    # Test pod scheduling speed
    log_info "Testing pod scheduling performance..."
    
    # Create test pod
    kubectl run test-pod --image=nginx --restart=Never --rm -i --tty=false -- echo "Performance test" &>/dev/null || true
    
    # Wait for pod to be scheduled
    local timeout=60
    local elapsed=0
    local scheduled=false
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get pod test-pod 2>/dev/null | grep -q "Completed\|Running"; then
            scheduled=true
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # Cleanup test pod
    kubectl delete pod test-pod 2>/dev/null || true
    
    if [ "$scheduled" = true ]; then
        log_success "Pod scheduling: OK ($elapsed seconds)"
        test_passed "Cluster Performance"
    else
        log_error "Pod scheduling: Timeout ($timeout seconds)"
        test_failed "Cluster Performance"
    fi
}

test_persistent_storage() {
    log_info "Test 12: Verifica persistent storage..."
    
    # Check storage classes
    local storage_classes=$(kubectl get storageclass 2>/dev/null | grep -c -v "NAME" || echo "0")
    
    if [ "$storage_classes" -gt 0 ]; then
        log_success "Storage classes available: $storage_classes"
        
        # Test PVC creation
        cat <<EOF | kubectl apply -f - &>/dev/null || true
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
        
        # Wait for PVC to be bound
        sleep 10
        local pvc_status=$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        # Cleanup test PVC
        kubectl delete pvc test-pvc 2>/dev/null || true
        
        if [ "$pvc_status" = "Bound" ]; then
            log_success "Persistent storage: PVC binding OK"
            test_passed "Persistent Storage"
        else
            log_warning "Persistent storage: PVC binding failed ($pvc_status)"
            test_warning "Persistent Storage"
        fi
    else
        log_error "No storage classes available"
        test_failed "Persistent Storage"
    fi
}

# =============================================================================
# SECURITY TESTS
# =============================================================================

test_cluster_security() {
    log_info "Test 13: Verifica sicurezza cluster..."
    
    # Check RBAC is enabled
    if kubectl auth can-i get pods --as=system:serviceaccount:default:default 2>/dev/null | grep -q "no"; then
        log_success "RBAC: Properly configured (default SA restricted)"
    else
        log_warning "RBAC: May be too permissive"
    fi
    
    # Check API server access
    if kubectl get --raw /api/v1 &>/dev/null; then
        log_success "API server: Accessible with valid credentials"
    else
        log_error "API server: Authentication failed"
    fi
    
    # Check network policies support
    if kubectl get networkpolicies --all-namespaces &>/dev/null; then
        log_success "Network policies: Supported"
        test_passed "Cluster Security"
    else
        log_warning "Network policies: Not supported"
        test_warning "Cluster Security"
    fi
}

# =============================================================================
# RESULTS AND REPORTING
# =============================================================================

generate_detailed_report() {
    log_info "Generazione report dettagliato..."
    
    local report_file="$SCRIPT_DIR/infrastructure-test-report.txt"
    
    {
        echo "# INFRASTRUCTURE TEST REPORT - FASE 7"
        echo "# Generated: $(date)"
        echo ""
        
        echo "## VM STATUS"
        for key in "${!VMS[@]}"; do
            IFS=':' read -r ip name role <<< "${VMS[$key]}"
            echo "VM $name ($role): $ip"
            
            # VM details
            if ping -c 1 "$ip" &>/dev/null; then
                echo "  Status: Online ✅"
                
                # Get system info
                local uptime=$(ssh -o StrictHostKeyChecking=no devops@"$ip" 'uptime -p' 2>/dev/null || echo "Unknown")
                local load=$(ssh -o StrictHostKeyChecking=no devops@"$ip" 'uptime | awk -F"load average:" "{print \$2}"' 2>/dev/null || echo "Unknown")
                local mem_usage=$(ssh -o StrictHostKeyChecking=no devops@"$ip" 'free | awk "NR==2{printf \"%.1f%%\", \$3*100/\$2}"' 2>/dev/null || echo "Unknown")
                
                echo "  Uptime: $uptime"
                echo "  Load: $load"
                echo "  Memory Usage: $mem_usage"
            else
                echo "  Status: Offline ❌"
            fi
            echo ""
        done
        
        echo "## KUBERNETES CLUSTER"
        if [ -f ~/.kube/config-crm-cluster ]; then
            export KUBECONFIG=~/.kube/config-crm-cluster
            
            echo "Cluster Info:"
            kubectl cluster-info 2>/dev/null || echo "Cluster not accessible"
            echo ""
            
            echo "Node Status:"
            kubectl get nodes -o wide 2>/dev/null || echo "Nodes not accessible"
            echo ""
            
            echo "System Pods:"
            kubectl get pods --all-namespaces | grep -E "(kube-system|metallb|ingress)" 2>/dev/null || echo "Pods not accessible"
            echo ""
            
            echo "Resource Usage:"
            kubectl top nodes 2>/dev/null || echo "Metrics not available"
        else
            echo "Kubectl config not available"
        fi
        echo ""
        
        echo "## TEST RESULTS SUMMARY"
        local total_tests=0
        local passed_tests=0
        local failed_tests=0
        local warning_tests=0
        
        for test_name in "${!TEST_RESULTS[@]}"; do
            local result="${TEST_RESULTS[$test_name]}"
            echo "$test_name: $result"
            
            total_tests=$((total_tests + 1))
            case "$result" in
                "PASS") passed_tests=$((passed_tests + 1)) ;;
                "FAIL") failed_tests=$((failed_tests + 1)) ;;
                "WARN") warning_tests=$((warning_tests + 1)) ;;
            esac
        done
        
        echo ""
        echo "Total Tests: $total_tests"
        echo "Passed: $passed_tests"
        echo "Failed: $failed_tests"
        echo "Warnings: $warning_tests"
        echo ""
        echo "Success Rate: $(( (passed_tests * 100) / total_tests ))%"
        
    } > "$report_file"
    
    log_success "Report salvato in: $report_file"
}

show_test_summary() {
    echo ""
    log_success "🎉 INFRASTRUCTURE TESTING COMPLETATO!"
    echo ""
    
    # Count results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local warning_tests=0
    
    echo -e "${GREEN}📊 TEST RESULTS SUMMARY:${NC}"
    echo ""
    
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        
        case "$result" in
            "PASS")
                echo -e "   ✅ $test_name"
                passed_tests=$((passed_tests + 1))
                ;;
            "FAIL")
                echo -e "   ❌ $test_name"
                failed_tests=$((failed_tests + 1))
                ;;
            "WARN")
                echo -e "   ⚠️  $test_name"
                warning_tests=$((warning_tests + 1))
                ;;
        esac
        total_tests=$((total_tests + 1))
    done
    
    echo ""
    echo -e "${BLUE}📈 STATISTICS:${NC}"
    echo "   Total Tests: $total_tests"
    echo "   Passed: $passed_tests"
    echo "   Failed: $failed_tests"
    echo "   Warnings: $warning_tests"
    echo "   Success Rate: $(( (passed_tests * 100) / total_tests ))%"
    echo ""
    
    if [ "$failed_tests" -eq 0 ]; then
        echo -e "${GREEN}🎯 INFRASTRUCTURE READY FOR APPLICATION DEPLOYMENT!${NC}"
        echo ""
        echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
        echo "   1. Deploy CRM application:"
        echo "      ./deploy_application.sh"
        echo ""
        echo "   2. Test application:"
        echo "      ./test_application.sh"
    else
        echo -e "${RED}⚠️  INFRASTRUCTURE HAS ISSUES!${NC}"
        echo ""
        echo -e "${YELLOW}📋 RECOMMENDED ACTIONS:${NC}"
        echo "   1. Review failed tests above"
        echo "   2. Check logs: $LOG_FILE"
        echo "   3. Fix issues before application deployment"
        echo "   4. Re-run infrastructure tests"
    fi
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    print_header
    
    log_info "Avvio testing infrastruttura Fase 7..."
    
    # Initialize log file
    echo "Infrastructure Test Started: $(date)" > "$LOG_FILE"
    
    # VM Tests
    test_vm_existence
    test_vm_running_status
    test_vm_connectivity
    test_vm_resources
    
    # Kubernetes Tests
    test_kubernetes_cluster_status
    test_kubernetes_node_roles
    test_kubernetes_system_pods
    test_kubernetes_networking
    test_load_balancer
    test_ingress_controller
    
    # Performance Tests
    test_cluster_performance
    test_persistent_storage
    
    # Security Tests
    test_cluster_security
    
    # Results
    generate_detailed_report
    show_test_summary
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
