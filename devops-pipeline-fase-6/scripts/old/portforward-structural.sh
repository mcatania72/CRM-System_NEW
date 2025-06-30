#!/bin/bash

# ================================
# PORT-FORWARD STRUTTURALE CRM - FASE 6
# Servizi systemd per port-forward permanenti su porte 30002/30003
# ================================

set -euo pipefail

NAMESPACE="crm-system"
FRONTEND_PORT="30002"
BACKEND_PORT="30003"
DEV_VM_IP="192.168.1.29"

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

echo "=== 🔄 PORT-FORWARD STRUTTURALE CRM - Porte 30002/30003 ==="
echo "Frontend Port: $FRONTEND_PORT"
echo "Backend Port: $BACKEND_PORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: CREA SERVIZI SYSTEMD
# ================================
create_portforward_services() {
    log_info "📋 Creazione servizi systemd port-forward..."
    
    # Frontend service 30002
    sudo tee /etc/systemd/system/crm-frontend-pf.service << EOF
[Unit]
Description=CRM Frontend Port Forward 30002
After=k3s.service
Requires=k3s.service

[Service]
Type=simple
User=devops
Group=devops
Environment=KUBECONFIG=/etc/rancher/k3s/k3s.yaml
ExecStart=/usr/local/bin/kubectl port-forward --address=0.0.0.0 service/frontend-service $FRONTEND_PORT:80 -n $NAMESPACE
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Backend service 30003
    sudo tee /etc/systemd/system/crm-backend-pf.service << EOF
[Unit]
Description=CRM Backend Port Forward 30003
After=k3s.service
Requires=k3s.service

[Service]
Type=simple
User=devops
Group=devops
Environment=KUBECONFIG=/etc/rancher/k3s/k3s.yaml
ExecStart=/usr/local/bin/kubectl port-forward --address=0.0.0.0 service/backend-service $BACKEND_PORT:4001 -n $NAMESPACE
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

    log_success "✅ Servizi systemd creati"
}

# ================================
# FUNZIONE: ABILITA E AVVIA SERVIZI
# ================================
start_portforward_services() {
    log_info "🚀 Abilitazione e avvio servizi port-forward..."
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Abilita servizi
    sudo systemctl enable crm-frontend-pf crm-backend-pf
    
    # Avvia servizi
    sudo systemctl start crm-frontend-pf crm-backend-pf
    
    # Attendi che si avviino
    sleep 5
    
    log_success "✅ Servizi port-forward avviati"
}

# ================================
# FUNZIONE: VERIFICA SERVIZI
# ================================
verify_portforward_services() {
    log_info "🔍 Verifica servizi port-forward..."
    
    # Status servizi
    echo ""
    echo "=== FRONTEND SERVICE STATUS ==="
    sudo systemctl status crm-frontend-pf --no-pager -l
    
    echo ""
    echo "=== BACKEND SERVICE STATUS ==="
    sudo systemctl status crm-backend-pf --no-pager -l
    
    # Verifica porte in ascolto
    echo ""
    echo "=== PORTE IN ASCOLTO ==="
    sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "Nessuna porta trovata"
    
    # Test connettività locale
    echo ""
    echo "=== TEST CONNETTIVITÀ LOCALE ==="
    if curl -s --connect-timeout 3 "http://localhost:$FRONTEND_PORT" > /dev/null; then
        log_success "✅ Frontend localhost:$FRONTEND_PORT OK"
    else
        log_error "❌ Frontend localhost:$FRONTEND_PORT FAIL"
    fi
    
    if curl -s --connect-timeout 3 "http://localhost:$BACKEND_PORT/api/health" > /dev/null; then
        log_success "✅ Backend localhost:$BACKEND_PORT OK"
    else
        log_error "❌ Backend localhost:$BACKEND_PORT FAIL"
    fi
}

# ================================
# FUNZIONE: CLEANUP SERVIZI
# ================================
cleanup_portforward_services() {
    log_warning "🗑️ Rimozione servizi port-forward..."
    
    # Stop servizi
    sudo systemctl stop crm-frontend-pf crm-backend-pf 2>/dev/null || true
    
    # Disabilita servizi
    sudo systemctl disable crm-frontend-pf crm-backend-pf 2>/dev/null || true
    
    # Rimuovi file servizi
    sudo rm -f /etc/systemd/system/crm-frontend-pf.service
    sudo rm -f /etc/systemd/system/crm-backend-pf.service
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    log_success "✅ Servizi port-forward rimossi"
}

# ================================
# FUNZIONE: SHOW ACCESS INFO
# ================================
show_access_info() {
    echo ""
    echo "=== 🎯 ACCESS INFORMATION ==="
    echo "🎨 Frontend:     http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "🔌 Backend API:  http://$DEV_VM_IP:$BACKEND_PORT/api"
    echo "🔑 Login:        admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "curl -I http://$DEV_VM_IP:$BACKEND_PORT/api/health"
    echo ""
    echo "=== 📊 ARCHITETTURA FINALE ==="
    echo "Host Windows → VM:$FRONTEND_PORT → Port-Forward → Frontend Pods"
    echo "Host Windows → VM:$BACKEND_PORT → Port-Forward → Backend Pods"
    echo ""
    echo "🎉 PORTE ORIGINALI ATTIVE TRAMITE PORT-FORWARD STRUTTURALE!"
}

# ================================
# FUNZIONE: STATUS
# ================================
show_status() {
    log_info "📊 Status port-forward strutturale..."
    
    echo ""
    echo "=== SERVIZI SYSTEMD ==="
    systemctl list-units --type=service | grep crm-.*-pf || echo "Nessun servizio trovato"
    
    echo ""
    echo "=== PROCESSI PORT-FORWARD ==="
    ps aux | grep "kubectl port-forward" | grep -v grep || echo "Nessun processo trovato"
    
    echo ""
    echo "=== PORTE ATTIVE ==="
    sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "Nessuna porta attiva"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-deploy}" in
        "deploy"|"create"|"start")
            create_portforward_services
            start_portforward_services
            verify_portforward_services
            show_access_info
            ;;
        "verify"|"test")
            verify_portforward_services
            show_access_info
            ;;
        "status")
            show_status
            ;;
        "cleanup"|"delete"|"stop")
            cleanup_portforward_services
            ;;
        "restart")
            log_info "🔄 Restart servizi port-forward..."
            sudo systemctl restart crm-frontend-pf crm-backend-pf
            sleep 3
            verify_portforward_services
            ;;
        "help"|*)
            echo "Usage: $0 {deploy|verify|status|restart|cleanup}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Crea e avvia servizi port-forward strutturali"
            echo "  verify   - Verifica servizi esistenti"
            echo "  status   - Mostra status servizi e processi"
            echo "  restart  - Riavvia servizi port-forward"
            echo "  cleanup  - Rimuove servizi port-forward"
            echo ""
            echo "Port-forward strutturale tramite systemd:"
            echo "- Frontend: 30002 → service/frontend-service:80"
            echo "- Backend:  30003 → service/backend-service:4001"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
