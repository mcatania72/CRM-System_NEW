#!/bin/bash

# ================================
# FIX DEFINITIVO k3s NodePort BINDING
# Risolve il problema di binding mancante 30002/30003
# ================================

set -euo pipefail

NAMESPACE="crm-system"
DEV_VM_IP="192.168.1.29"
FRONTEND_PORT="30002"
BACKEND_PORT="30003"

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

echo "=== 🔧 FIX DEFINITIVO k3s NodePort BINDING ==="
echo "Target: $DEV_VM_IP:$FRONTEND_PORT, $DEV_VM_IP:$BACKEND_PORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: BACKUP SICURO
# ================================
create_backup() {
    log_info "💾 Backup configurazioni..."
    local backup_dir="/tmp/k8s-nodeport-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup servizi
    kubectl get services -n "$NAMESPACE" -o yaml > "$backup_dir/services.yaml" 2>/dev/null || true
    
    # Backup k3s config
    sudo systemctl cat k3s > "$backup_dir/k3s-service.txt" 2>/dev/null || true
    
    echo "$backup_dir" > /tmp/k8s-nodeport-last-backup
    log_success "✅ Backup: $backup_dir"
}

# ================================
# FUNZIONE: FIX SERVIZI CON EXTERNAL IPs
# ================================
fix_services_external_ip() {
    log_info "🔧 Fix servizi con externalIPs..."
    
    # Frontend service con externalIPs
    kubectl patch service frontend-service -n "$NAMESPACE" --patch="
spec:
  type: NodePort
  externalTrafficPolicy: Cluster
  externalIPs: [\"$DEV_VM_IP\"]
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: $FRONTEND_PORT
    protocol: TCP
" || { log_error "❌ Frontend service patch failed"; return 1; }

    # Backend service con externalIPs  
    kubectl patch service backend-service -n "$NAMESPACE" --patch="
spec:
  type: NodePort
  externalTrafficPolicy: Cluster
  externalIPs: [\"$DEV_VM_IP\"]
  ports:
  - name: http
    port: 4001
    targetPort: 4001
    nodePort: $BACKEND_PORT
    protocol: TCP
" || { log_error "❌ Backend service patch failed"; return 1; }

    log_success "✅ Servizi aggiornati con externalIPs"
}

# ================================
# FUNZIONE: CONFIGURAZIONE k3s NODE-EXTERNAL-IP
# ================================
configure_k3s_external_ip() {
    log_info "🔧 Configurazione k3s node-external-ip..."
    
    # Check configurazione attuale
    local current_config=$(sudo systemctl cat k3s | grep "ExecStart=")
    
    if echo "$current_config" | grep -q "node-external-ip"; then
        log_info "📋 node-external-ip già configurato"
        echo "$current_config" | grep "node-external-ip"
    else
        log_info "➕ Aggiunta node-external-ip a k3s"
        
        # Backup del file service
        sudo cp /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.backup
        
        # Aggiungi node-external-ip alla configurazione
        sudo sed -i "/ExecStart=.*k3s.*server/ s/$/ --node-external-ip=$DEV_VM_IP/" /etc/systemd/system/k3s.service
        
        # Reload systemd
        sudo systemctl daemon-reload
        
        log_success "✅ k3s configurato con node-external-ip"
    fi
}

# ================================
# FUNZIONE: RESTART k3s SICURO CON VERIFICA
# ================================
restart_k3s_with_verification() {
    log_info "🔄 Restart k3s con verifica..."
    
    # Verifica stato prima del restart
    if ! sudo systemctl is-active --quiet k3s; then
        log_error "❌ k3s non attivo prima del restart"
        return 1
    fi
    
    log_info "⏳ Restarting k3s..."
    sudo systemctl restart k3s
    
    # Wait con timeout esteso
    local timeout=180  # 3 minuti
    local elapsed=0
    
    log_info "⏳ Waiting for k3s cluster ready..."
    while [ $elapsed -lt $timeout ]; do
        if kubectl cluster-info &> /dev/null && kubectl get nodes &> /dev/null; then
            log_success "✅ k3s cluster ready ($elapsed s)"
            break
        fi
        
        sleep 5
        ((elapsed+=5))
        echo -n "."
    done
    
    if [ $elapsed -ge $timeout ]; then
        log_error "❌ k3s restart timeout ($timeout s)"
        return 1
    fi
    
    # Verifica pods
    log_info "⏳ Waiting for pods ready..."
    kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=120s || log_warning "⚠️ Some pods not ready"
    
    log_success "✅ k3s restart completed"
}

# ================================
# FUNZIONE: VERIFICA BINDING POST-FIX
# ================================
verify_nodeport_binding() {
    log_info "🔍 Verifica NodePort binding..."
    
    # Wait stabilizzazione
    sleep 30
    
    local binding_ok=true
    
    # Test binding porte
    if sudo netstat -tulpn | grep -q ":$FRONTEND_PORT"; then
        log_success "✅ Porta $FRONTEND_PORT in ascolto"
    else
        log_error "❌ Porta $FRONTEND_PORT NON in ascolto"
        binding_ok=false
    fi
    
    if sudo netstat -tulpn | grep -q ":$BACKEND_PORT"; then
        log_success "✅ Porta $BACKEND_PORT in ascolto"
    else
        log_error "❌ Porta $BACKEND_PORT NON in ascolto"
        binding_ok=false
    fi
    
    # Test connettività locale
    log_info "🧪 Test connettività locale..."
    if curl -s --connect-timeout 5 "http://localhost:$FRONTEND_PORT" > /dev/null; then
        log_success "✅ Frontend localhost OK"
    else
        log_warning "⚠️ Frontend localhost FAIL"
        binding_ok=false
    fi
    
    if curl -s --connect-timeout 5 "http://localhost:$BACKEND_PORT/api/health" > /dev/null; then
        log_success "✅ Backend localhost OK"
    else
        log_warning "⚠️ Backend localhost FAIL"
        binding_ok=false
    fi
    
    # Test connettività esterna
    log_info "🌐 Test connettività esterna..."
    if curl -s --connect-timeout 5 "http://$DEV_VM_IP:$FRONTEND_PORT" > /dev/null; then
        log_success "✅ Frontend esterno OK"
    else
        log_warning "⚠️ Frontend esterno FAIL"
        binding_ok=false
    fi
    
    if [ "$binding_ok" = true ]; then
        log_success "✅ NodePort binding completo!"
        return 0
    else
        log_error "❌ NodePort binding parziale/fallito"
        return 1
    fi
}

# ================================
# FUNZIONE: MOSTRA RISULTATI FINALI
# ================================
show_final_results() {
    log_info "📊 Risultati finali..."
    
    echo ""
    echo "=== NETWORK BINDING STATUS ==="
    sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "❌ Nessun binding trovato"
    
    echo ""
    echo "=== KUBERNETES SERVICES ==="
    kubectl get services -n "$NAMESPACE" -o wide
    
    echo ""
    echo "=== ACCESS INFORMATION ==="
    echo "🎨 Frontend: http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "🔌 Backend:  http://$DEV_VM_IP:$BACKEND_PORT/api"
    echo "🔑 Login:    admin@crm.local / admin123"
    
    echo ""
    echo "=== TEST COMMANDS ==="
    echo "Da DEV_VM:     curl -I http://localhost:$FRONTEND_PORT"
    echo "Da Windows:    curl -I http://$DEV_VM_IP:$FRONTEND_PORT"
}

# ================================
# FUNZIONE: ROLLBACK
# ================================
rollback() {
    log_warning "🔄 Rollback configurazioni..."
    
    local backup_dir=$(cat /tmp/k8s-nodeport-last-backup 2>/dev/null || echo "")
    
    if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
        log_info "📂 Usando backup: $backup_dir"
        
        # Restore servizi
        if [ -f "$backup_dir/services.yaml" ]; then
            kubectl apply -f "$backup_dir/services.yaml" 2>/dev/null || true
        fi
        
        # Restore k3s config
        if [ -f "$backup_dir/k3s-service.txt" ] && [ -f "/etc/systemd/system/k3s.service.backup" ]; then
            sudo cp /etc/systemd/system/k3s.service.backup /etc/systemd/system/k3s.service
            sudo systemctl daemon-reload
            sudo systemctl restart k3s
        fi
        
        log_success "✅ Rollback completato"
    else
        log_error "❌ Backup non trovato"
    fi
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-fix}" in
        "fix")
            create_backup
            fix_services_external_ip
            configure_k3s_external_ip
            restart_k3s_with_verification
            verify_nodeport_binding
            show_final_results
            ;;
        "verify")
            verify_nodeport_binding
            show_final_results
            ;;
        "rollback")
            rollback
            ;;
        "help"|*)
            echo "Usage: $0 {fix|verify|rollback}"
            echo ""
            echo "Commands:"
            echo "  fix      - Applica fix completo NodePort binding"
            echo "  verify   - Verifica binding esistente"
            echo "  rollback - Rollback a configurazione precedente"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
