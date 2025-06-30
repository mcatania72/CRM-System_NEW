#!/bin/bash

# ================================
# PORT-FORWARD STRUTTURALE PORTE ORIGINALI 30002/30003
# Mantiene port-forward permanenti sulle porte concordate
# ================================

set -euo pipefail

NAMESPACE="crm-system"
FRONTEND_PORT="30002"  # Porta originale concordata
BACKEND_PORT="30003"   # Porta originale concordata
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

echo "=== 🔄 PORT-FORWARD PORTE ORIGINALI 30002/30003 ==="
echo "Frontend Port: $FRONTEND_PORT"
echo "Backend Port: $BACKEND_PORT"
echo "DEV_VM IP: $DEV_VM_IP"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: VERIFICA PORTE LIBERE
# ================================
check_port_availability() {
    local port=$1
    local service_name=$2
    
    log_info "🔍 Verifica disponibilità porta $port ($service_name)..."
    
    if sudo netstat -tulpn | grep -q ":$port "; then
        local process=$(sudo netstat -tulpn | grep ":$port " | awk '{print $7}')
        log_warning "⚠️ Porta $port già in uso da: $process"
        return 1
    else
        log_success "✅ Porta $port disponibile"
        return 0
    fi
}

# ================================
# FUNZIONE: CLEANUP COMPLETO
# ================================
cleanup_portforward() {
    log_info "🧹 Cleanup port-forward esistenti..."
    
    # Kill processi port-forward specifici
    sudo pkill -f "kubectl port-forward.*service/frontend-service.*$FRONTEND_PORT:80" 2>/dev/null || true
    sudo pkill -f "kubectl port-forward.*service/backend-service.*$BACKEND_PORT:4001" 2>/dev/null || true
    
    # Kill tutti i port-forward kubectl
    sudo pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Stop servizi systemd se esistono
    sudo systemctl stop crm-frontend-pf 2>/dev/null || true
    sudo systemctl stop crm-backend-pf 2>/dev/null || true
    
    # Rimuovi regole firewall port-forward temporanee
    sudo ufw --force delete allow $FRONTEND_PORT/tcp comment "CRM Frontend Port-Forward" 2>/dev/null || true
    sudo ufw --force delete allow $BACKEND_PORT/tcp comment "CRM Backend Port-Forward" 2>/dev/null || true
    
    # Attendi cleanup
    sleep 2
    
    log_success "✅ Cleanup completato"
}

# ================================
# FUNZIONE: SETUP PORT-FORWARD MANUALE
# ================================
setup_manual_portforward() {
    log_info "🚀 Setup port-forward manuale su porte originali..."
    
    # Verifica che i servizi k8s esistano
    if ! kubectl get service frontend-service -n $NAMESPACE >/dev/null 2>&1; then
        log_error "❌ Servizio frontend-service non trovato"
        return 1
    fi
    
    if ! kubectl get service backend-service -n $NAMESPACE >/dev/null 2>&1; then
        log_error "❌ Servizio backend-service non trovato"
        return 1
    fi
    
    # Apri porte nel firewall
    log_info "🔥 Apertura porte nel firewall UFW..."
    sudo ufw allow $FRONTEND_PORT/tcp comment "CRM Frontend Port-Forward"
    sudo ufw allow $BACKEND_PORT/tcp comment "CRM Backend Port-Forward"
    
    # Avvia port-forward in background
    log_info "🔄 Avvio port-forward frontend ($FRONTEND_PORT)..."
    nohup kubectl port-forward -n $NAMESPACE --address=0.0.0.0 service/frontend-service $FRONTEND_PORT:80 > /tmp/frontend-pf.log 2>&1 &
    FRONTEND_PID=$!
    
    log_info "🔄 Avvio port-forward backend ($BACKEND_PORT)..."
    nohup kubectl port-forward -n $NAMESPACE --address=0.0.0.0 service/backend-service $BACKEND_PORT:4001 > /tmp/backend-pf.log 2>&1 &
    BACKEND_PID=$!
    
    # Salva PID per cleanup futuro
    echo $FRONTEND_PID > /tmp/frontend-pf.pid
    echo $BACKEND_PID > /tmp/backend-pf.pid
    
    # Attendi che si avviino
    sleep 5
    
    # Verifica che siano attivi
    if kill -0 $FRONTEND_PID 2>/dev/null && kill -0 $BACKEND_PID 2>/dev/null; then
        log_success "✅ Port-forward avviati con successo"
        return 0
    else
        log_error "❌ Errore nell'avvio port-forward"
        return 1
    fi
}

# ================================
# FUNZIONE: SETUP SERVIZI SYSTEMD
# ================================
setup_systemd_portforward() {
    log_info "⚙️ Setup servizi systemd per port-forward permanenti..."
    
    # Frontend service
    sudo tee /etc/systemd/system/crm-frontend-pf.service > /dev/null << EOF
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

    # Backend service
    sudo tee /etc/systemd/system/crm-backend-pf.service > /dev/null << EOF
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

    # Reload systemd e avvia servizi
    sudo systemctl daemon-reload
    sudo systemctl enable crm-frontend-pf crm-backend-pf
    sudo systemctl start crm-frontend-pf crm-backend-pf
    
    # Attendi avvio
    sleep 5
    
    log_success "✅ Servizi systemd configurati e avviati"
}

# ================================
# FUNZIONE: VERIFICA PORT-FORWARD
# ================================
verify_portforward() {
    log_info "🔍 Verifica port-forward attivi..."
    
    # Verifica processi
    echo ""
    echo "=== PROCESSI PORT-FORWARD ==="
    ps aux | grep "kubectl port-forward" | grep -v grep || echo "Nessun processo port-forward trovato"
    
    # Verifica porte in ascolto
    echo ""
    echo "=== PORTE IN ASCOLTO ==="
    sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "Porte non in ascolto"
    
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
    
    # Test IP esterno (per host Windows)
    echo ""
    echo "=== TEST IP ESTERNO ==="
    if curl -s --connect-timeout 3 "http://$DEV_VM_IP:$FRONTEND_PORT" > /dev/null; then
        log_success "✅ Frontend $DEV_VM_IP:$FRONTEND_PORT OK"
    else
        log_error "❌ Frontend $DEV_VM_IP:$FRONTEND_PORT FAIL"
    fi
    
    if curl -s --connect-timeout 3 "http://$DEV_VM_IP:$BACKEND_PORT/api/health" > /dev/null; then
        log_success "✅ Backend $DEV_VM_IP:$BACKEND_PORT OK"
    else
        log_error "❌ Backend $DEV_VM_IP:$BACKEND_PORT FAIL"
    fi
}

# ================================
# FUNZIONE: SHOW ACCESS INFO
# ================================
show_access_info() {
    echo ""
    echo "=== 🎯 ACCESS INFORMATION - PORTE ORIGINALI ==="
    echo "🎨 Frontend:     http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "🔌 Backend API:  http://$DEV_VM_IP:$BACKEND_PORT/api"
    echo "🔑 Login:        admin@crm.local / admin123"
    echo ""
    echo "=== 🧪 TEST DA HOST WINDOWS ==="
    echo "curl -I http://$DEV_VM_IP:$FRONTEND_PORT"
    echo "curl -I http://$DEV_VM_IP:$BACKEND_PORT/api/health"
    echo ""
    echo "=== 📊 ARCHITETTURA ==="
    echo "Host Windows → VM:30002 → Port-Forward → Frontend Pods"
    echo "Host Windows → VM:30003 → Port-Forward → Backend Pods"
    echo ""
    echo "🎉 PORTE ORIGINALI 30002/30003 ATTIVE TRAMITE PORT-FORWARD!"
}

# ================================
# FUNZIONE: STATUS
# ================================
show_status() {
    log_info "📊 Status port-forward porte originali..."
    
    echo ""
    echo "=== SERVIZI SYSTEMD ==="
    systemctl is-active crm-frontend-pf 2>/dev/null && echo "Frontend systemd: ATTIVO" || echo "Frontend systemd: NON ATTIVO"
    systemctl is-active crm-backend-pf 2>/dev/null && echo "Backend systemd: ATTIVO" || echo "Backend systemd: NON ATTIVO"
    
    verify_portforward
    show_access_info
}

# ================================
# FUNZIONE: CLEANUP SERVIZI SYSTEMD
# ================================
cleanup_systemd_services() {
    log_warning "🗑️ Rimozione servizi systemd port-forward..."
    
    # Stop e disabilita servizi
    sudo systemctl stop crm-frontend-pf crm-backend-pf 2>/dev/null || true
    sudo systemctl disable crm-frontend-pf crm-backend-pf 2>/dev/null || true
    
    # Rimuovi file servizi
    sudo rm -f /etc/systemd/system/crm-frontend-pf.service
    sudo rm -f /etc/systemd/system/crm-backend-pf.service
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    log_success "✅ Servizi systemd rimossi"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-manual}" in
        "manual"|"start")
            cleanup_portforward
            if check_port_availability $FRONTEND_PORT "Frontend" && check_port_availability $BACKEND_PORT "Backend"; then
                setup_manual_portforward
                verify_portforward
                show_access_info
            else
                log_error "❌ Porte non disponibili. Usa 'cleanup' prima del deploy"
                exit 1
            fi
            ;;
        "systemd"|"service")
            cleanup_portforward
            cleanup_systemd_services
            setup_systemd_portforward
            verify_portforward
            show_access_info
            ;;
        "verify"|"test")
            verify_portforward
            show_access_info
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_portforward
            cleanup_systemd_services
            ;;
        "restart")
            log_info "🔄 Restart port-forward..."
            cleanup_portforward
            sleep 2
            setup_manual_portforward
            verify_portforward
            ;;
        "help"|*)
            echo "Usage: $0 {manual|systemd|verify|status|restart|cleanup}"
            echo ""
            echo "Commands:"
            echo "  manual   - Port-forward manuale su porte 30002/30003 (default)"
            echo "  systemd  - Port-forward permanente tramite servizi systemd"
            echo "  verify   - Verifica port-forward esistenti"
            echo "  status   - Status completo port-forward"
            echo "  restart  - Riavvia port-forward"
            echo "  cleanup  - Rimuove tutti i port-forward"
            echo ""
            echo "PORTE ORIGINALI: 30002 (Frontend) e 30003 (Backend)"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
