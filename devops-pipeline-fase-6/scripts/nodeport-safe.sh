#!/bin/bash

# ================================
# SCRIPT NODEPORT SICURO - FASE 6  
# ZERO OPERAZIONI PERICOLOSE
# ================================

set -euo pipefail

# Configurazione
NAMESPACE="crm-system"
FRONTEND_PORT="30002"
BACKEND_PORT="30003"
DEV_VM_IP="192.168.1.29"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni utility
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
echo "=== 🛡️ NODEPORT SICURO: 30002/30003 ==="
echo "Timestamp: $(date)"
echo "DEV_VM IP: ${DEV_VM_IP}"
echo ""

# ================================
# FUNZIONE: BACKUP AUTOMATICO
# ================================
create_backup() {
    log_info "🛡️ Creazione backup configurazioni..."
    
    local backup_dir="/tmp/k8s-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup servizi
    kubectl get services -n "$NAMESPACE" -o yaml > "$backup_dir/services.yaml" 2>/dev/null || true
    kubectl get configmaps -n "$NAMESPACE" -o yaml > "$backup_dir/configmaps.yaml" 2>/dev/null || true
    
    # Backup UFW rules  
    sudo ufw status numbered > "$backup_dir/ufw-rules.txt" 2>/dev/null || true
    
    echo "$backup_dir" > /tmp/k8s-last-backup
    log_success "✅ Backup salvato in: $backup_dir"
}

# ================================  
# FUNZIONE: PREREQUISITI CHECK
# ================================
check_prerequisites() {
    log_info "🔍 Verifica prerequisiti..."
    
    local errors=0
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "❌ kubectl non trovato"
        ((errors++))
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "❌ Cluster k3s non raggiungibile"  
        ((errors++))
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "❌ Namespace $NAMESPACE non esiste"
        ((errors++))
    fi
    
    # Check pods running
    local pods_ready=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep "1/1.*Running" | wc -l)
    if [ "$pods_ready" -lt 3 ]; then
        log_warning "⚠️ Solo $pods_ready pods ready (expected: 5+)"
    fi
    
    # Check firewall  
    if ! sudo ufw status | grep -q "Status: active"; then
        log_warning "⚠️ UFW firewall non attivo"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "❌ $errors errori prerequisiti. Impossibile procedere."
        exit 1
    fi
    
    log_success "✅ Prerequisiti OK"
}

# ================================
# FUNZIONE: VERIFICA NODEPORT BINDING  
# ================================
check_nodeport_binding() {
    log_info "🔍 Verifica NodePort binding..."
    
    local binding_issues=0
    
    # Check porte in ascolto
    if ! sudo netstat -tulpn | grep -q ":$FRONTEND_PORT"; then
        log_warning "⚠️ Porta $FRONTEND_PORT non in ascolto"
        ((binding_issues++))
    fi
    
    if ! sudo netstat -tulpn | grep -q ":$BACKEND_PORT"; then
        log_warning "⚠️ Porta $BACKEND_PORT non in ascolto"
        ((binding_issues++))
    fi
    
    if [ $binding_issues -eq 0 ]; then
        log_success "✅ NodePort binding OK"
        return 0
    else
        log_warning "⚠️ $binding_issues problemi binding NodePort"
        return 1
    fi
}

# ================================
# FUNZIONE: FIX SERVIZI (SICURO)
# ================================  
fix_services() {
    log_info "🔧 Fix configurazione servizi..."
    
    # Patch frontend service
    kubectl patch service frontend-service -n "$NAMESPACE" --patch='
spec:
  type: NodePort
  externalTrafficPolicy: Cluster
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30002
    protocol: TCP
' || log_warning "⚠️ Frontend service patch failed"

    # Patch backend service  
    kubectl patch service backend-service -n "$NAMESPACE" --patch='
spec:
  type: NodePort
  externalTrafficPolicy: Cluster
  ports:
  - name: http
    port: 4001
    targetPort: 4001
    nodePort: 30003
    protocol: TCP
' || log_warning "⚠️ Backend service patch failed"

    log_success "✅ Servizi aggiornati"
}

# ================================
# FUNZIONE: FIX FIREWALL (SICURO)
# ================================
fix_firewall() {
    log_info "🔧 Verifica/fix firewall..."
    
    # Check e aggiungi regole se mancanti
    if ! sudo ufw status numbered | grep -q "$FRONTEND_PORT/tcp"; then
        sudo ufw allow "$FRONTEND_PORT/tcp" comment "CRM Frontend K8s NodePort"
        log_info "➕ Aggiunta regola UFW $FRONTEND_PORT"
    fi
    
    if ! sudo ufw status numbered | grep -q "$BACKEND_PORT/tcp"; then
        sudo ufw allow "$BACKEND_PORT/tcp" comment "CRM Backend K8s NodePort"  
        log_info "➕ Aggiunta regola UFW $BACKEND_PORT"
    fi
    
    # Reload UFW (sicuro)
    sudo ufw reload
    log_success "✅ Firewall configurato"
}

# ================================
# FUNZIONE: RESTART K3S (SICURO)
# ================================  
restart_k3s_safe() {
    log_info "🔄 Restart k3s sicuro..."
    
    # Verifica che k3s sia attivo prima
    if ! sudo systemctl is-active --quiet k3s; then
        log_error "❌ k3s non attivo, impossibile restart"
        return 1
    fi
    
    log_info "⏳ Restarting k3s service..."
    sudo systemctl restart k3s
    
    # Wait con timeout
    local timeout=120
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl cluster-info &> /dev/null; then
            log_success "✅ k3s restart completato ($elapsed s)"
            return 0
        fi
        
        sleep 5
        ((elapsed+=5))
        echo -n "."
    done
    
    log_error "❌ k3s restart timeout ($timeout s)"
    return 1
}

# ================================
# FUNZIONE: TEST CONNETTIVITÀ
# ================================
test_connectivity() {
    log_info "🧪 Test connettività NodePort..."
    
    # Wait 30s per stabilizzazione
    log_info "⏳ Attesa stabilizzazione (30s)..."
    sleep 30
    
    # Test locale porte
    local frontend_status="❌"
    local backend_status="❌"
    
    if curl -s --connect-timeout 5 "http://localhost:$FRONTEND_PORT" > /dev/null; then
        frontend_status="✅"
    fi
    
    if curl -s --connect-timeout 5 "http://localhost:$BACKEND_PORT/api/health" > /dev/null; then
        backend_status="✅"
    fi
    
    echo "📊 RISULTATI TEST:"
    echo "Frontend (${FRONTEND_PORT}): $frontend_status"  
    echo "Backend (${BACKEND_PORT}): $backend_status"
    
    # Test esterno  
    log_info "🌐 Test accesso esterno..."
    echo "Frontend: http://${DEV_VM_IP}:${FRONTEND_PORT}"
    echo "Backend: http://${DEV_VM_IP}:${BACKEND_PORT}/api"
}

# ================================
# FUNZIONE: FALLBACK PORT-FORWARD
# ================================
setup_portforward_fallback() {
    log_warning "🔄 Setup fallback port-forward..."
    
    # Kill existing port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Setup port-forward con porte alternative
    kubectl port-forward -n "$NAMESPACE" --address=0.0.0.0 service/frontend-service 8090:80 &
    kubectl port-forward -n "$NAMESPACE" --address=0.0.0.0 service/backend-service 8091:4001 &
    
    sleep 5
    
    log_info "📊 FALLBACK ACCESS:"
    echo "Frontend: http://${DEV_VM_IP}:8090"
    echo "Backend: http://${DEV_VM_IP}:8091/api"
}

# ================================
# FUNZIONE: STATUS REPORT
# ================================
show_status() {
    log_info "📊 Status report completo..."
    
    echo ""
    echo "=== CLUSTER STATUS ==="
    kubectl get nodes --no-headers 2>/dev/null || echo "❌ Cluster error"
    
    echo ""  
    echo "=== PODS STATUS ==="
    kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "❌ Pods error"
    
    echo ""
    echo "=== SERVICES STATUS ==="
    kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null || echo "❌ Services error"
    
    echo ""
    echo "=== NODEPORT BINDING ==="
    sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "❌ No NodePort binding"
    
    echo ""
    echo "=== FIREWALL STATUS ==="  
    sudo ufw status numbered | grep -E "$FRONTEND_PORT|$BACKEND_PORT" || echo "❌ No firewall rules"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-help}" in
        "check")
            check_prerequisites
            check_nodeport_binding
            show_status
            ;;
            
        "fix")
            create_backup
            check_prerequisites
            fix_services
            fix_firewall
            restart_k3s_safe
            test_connectivity
            ;;
            
        "status")
            show_status
            ;;
            
        "fallback")
            setup_portforward_fallback
            ;;
            
        "help"|*)
            echo "Usage: $0 {check|fix|status|fallback}"
            echo ""
            echo "Commands:"
            echo "  check     - Verifica configurazioni senza modifiche"
            echo "  fix       - Fix completo NodePort 30002/30003"  
            echo "  status    - Mostra status dettagliato"
            echo "  fallback  - Setup port-forward se NodePort fallisce"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
