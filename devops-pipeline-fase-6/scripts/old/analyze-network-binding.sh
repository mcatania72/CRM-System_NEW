#!/bin/bash

# ================================
# ANALISI NETWORK BINDING k3s 
# Diagnosi completa problema NodePort host → VM
# ================================

set -euo pipefail

# Configurazione
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

echo "=== 🔍 ANALISI NETWORK BINDING k3s ==="
echo "Target: $DEV_VM_IP:$FRONTEND_PORT, $DEV_VM_IP:$BACKEND_PORT"
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: ANALISI BINDING DETTAGLIATA
# ================================
analyze_port_binding() {
    log_info "🔍 Analisi dettagliata binding porte..."
    
    echo ""
    echo "=== NETSTAT ANALYSIS ==="
    local netstat_output=$(sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "No ports found")
    echo "$netstat_output"
    
    if echo "$netstat_output" | grep -q "127.0.0.1"; then
        log_warning "⚠️ PROBLEMA: Binding solo su localhost (127.0.0.1)"
        echo "   → k3s non fa bind su interfaccia esterna"
    elif echo "$netstat_output" | grep -q "0.0.0.0"; then
        log_success "✅ Binding corretto su tutte le interfacce (0.0.0.0)"
    elif echo "$netstat_output" | grep -q ":::"; then
        log_info "📡 IPv6 binding trovato (:::)"
        echo "   → Potrebbe essere solo IPv6, verificare IPv4"
    else
        log_error "❌ Nessun binding trovato per porte $FRONTEND_PORT/$BACKEND_PORT"
    fi
    
    echo ""
    echo "=== SS ANALYSIS (più dettagliato) ==="
    local ss_output=$(sudo ss -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" || echo "No ports found")
    echo "$ss_output"
    
    echo ""
    echo "=== LSOF ANALYSIS (processo specifico) ==="
    echo "Frontend port $FRONTEND_PORT:"
    sudo lsof -i :$FRONTEND_PORT 2>/dev/null || echo "  No process listening"
    echo "Backend port $BACKEND_PORT:"
    sudo lsof -i :$BACKEND_PORT 2>/dev/null || echo "  No process listening"
}

# ================================
# FUNZIONE: ANALISI CONFIGURAZIONE k3s
# ================================
analyze_k3s_config() {
    log_info "🔧 Analisi configurazione k3s..."
    
    echo ""
    echo "=== K3S SERVICE CONFIGURATION ==="
    sudo systemctl cat k3s | grep -E "ExecStart|bind-address|node-ip|advertise-address" || echo "No binding config found"
    
    echo ""
    echo "=== K3S SERVER ARGS ==="
    ps aux | grep k3s | grep -v grep || echo "k3s process not found"
    
    echo ""
    echo "=== K3S NODE INFO ==="
    kubectl get nodes -o wide 2>/dev/null || echo "Cannot get node info"
    
    echo ""
    echo "=== TRAEFIK LOADBALANCER CONFIG ==="
    kubectl get svc traefik -n kube-system -o yaml 2>/dev/null | grep -A 15 -B 5 "nodePort\|externalIPs\|loadBalancerIP" || echo "Cannot get Traefik config"
}

# ================================
# FUNZIONE: TEST CONNETTIVITÀ MULTI-LIVELLO
# ================================
test_connectivity_levels() {
    log_info "🧪 Test connettività multi-livello..."
    
    echo ""
    echo "=== LOCAL LOCALHOST TEST ==="
    if curl -s --connect-timeout 3 "http://localhost:$FRONTEND_PORT" > /dev/null 2>&1; then
        log_success "✅ localhost:$FRONTEND_PORT OK"
    else
        log_error "❌ localhost:$FRONTEND_PORT FAIL"
    fi
    
    if curl -s --connect-timeout 3 "http://localhost:$BACKEND_PORT/api/health" > /dev/null 2>&1; then
        log_success "✅ localhost:$BACKEND_PORT OK"
    else
        log_error "❌ localhost:$BACKEND_PORT FAIL"
    fi
    
    echo ""
    echo "=== LOCAL IP TEST ==="
    if curl -s --connect-timeout 3 "http://127.0.0.1:$FRONTEND_PORT" > /dev/null 2>&1; then
        log_success "✅ 127.0.0.1:$FRONTEND_PORT OK"
    else
        log_error "❌ 127.0.0.1:$FRONTEND_PORT FAIL"
    fi
    
    echo ""
    echo "=== DEV_VM IP TEST (interno) ==="
    if curl -s --connect-timeout 3 "http://$DEV_VM_IP:$FRONTEND_PORT" > /dev/null 2>&1; then
        log_success "✅ $DEV_VM_IP:$FRONTEND_PORT OK"
    else
        log_error "❌ $DEV_VM_IP:$FRONTEND_PORT FAIL"
    fi
    
    echo ""
    echo "=== NETWORK INTERFACE TEST ==="
    local interfaces=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1)
    for ip in $interfaces; do
        echo "Testing interface: $ip"
        if curl -s --connect-timeout 2 "http://$ip:$FRONTEND_PORT" > /dev/null 2>&1; then
            log_success "✅ $ip:$FRONTEND_PORT OK"
        else
            log_warning "⚠️ $ip:$FRONTEND_PORT FAIL"
        fi
    done
}

# ================================
# FUNZIONE: ANALISI FIREWALL DETTAGLIATA
# ================================
analyze_firewall_detailed() {
    log_info "🔥 Analisi firewall dettagliata..."
    
    echo ""
    echo "=== UFW STATUS ==="
    sudo ufw status verbose
    
    echo ""
    echo "=== IPTABLES RULES (INPUT) ==="
    sudo iptables -L INPUT -n -v | head -20
    
    echo ""
    echo "=== IPTABLES NAT RULES ==="
    sudo iptables -t nat -L -n -v | grep -E "$FRONTEND_PORT|$BACKEND_PORT" || echo "No NAT rules for NodePort"
    
    echo ""
    echo "=== IPTABLES FORWARD RULES ==="
    sudo iptables -L FORWARD -n -v | head -10
}

# ================================
# FUNZIONE: PROPOSTA SOLUZIONI
# ================================
propose_solutions() {
    log_info "💡 Analisi problemi e soluzioni..."
    
    echo ""
    echo "=== DIAGNOSI PROBLEMI ==="
    
    # Analizza binding
    local binding_issue=false
    if sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" | grep -q "127.0.0.1"; then
        log_error "🔴 PROBLEMA 1: k3s bind solo su localhost"
        echo "   Causa: --bind-address=127.0.0.1 o configurazione di default"
        echo "   Fix: Modificare configurazione k3s per bind su 0.0.0.0"
        binding_issue=true
    fi
    
    # Analizza k3s args
    if ps aux | grep k3s | grep -q "bind-address"; then
        log_warning "🟡 k3s ha bind-address configurato"
        echo "   Verificare valore attuale"
    fi
    
    # Analizza IPv6 only
    if sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" | grep -q ":::" && ! sudo netstat -tulpn | grep -E ":$FRONTEND_PORT|:$BACKEND_PORT" | grep -q "0.0.0.0"; then
        log_warning "🟡 PROBLEMA 2: Solo binding IPv6"
        echo "   Causa: k3s potrebbe bindare solo su IPv6"
        echo "   Fix: Forzare dual-stack o IPv4"
    fi
    
    echo ""
    echo "=== SOLUZIONI PROPOSTE ==="
    echo "1. 🔧 Fix bind-address k3s:"
    echo "   sudo sed -i 's/--bind-address=[^ ]*/--bind-address=0.0.0.0/g' /etc/systemd/system/k3s.service"
    echo "   sudo systemctl daemon-reload && sudo systemctl restart k3s"
    echo ""
    echo "2. 🔧 Aggiungere node-external-ip:"
    echo "   --node-external-ip=$DEV_VM_IP"
    echo ""
    echo "3. 🔧 Fix Traefik LoadBalancer:"
    echo "   kubectl patch svc traefik -n kube-system -p '{\"spec\":{\"externalIPs\":[\"$DEV_VM_IP\"]}}'"
    echo ""
    echo "4. 🔧 Fix servizi con externalIPs:"
    echo "   kubectl patch svc frontend-service -n $NAMESPACE -p '{\"spec\":{\"externalIPs\":[\"$DEV_VM_IP\"]}}'"
    echo "   kubectl patch svc backend-service -n $NAMESPACE -p '{\"spec\":{\"externalIPs\":[\"$DEV_VM_IP\"]}}'"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-analyze}" in
        "analyze"|"check")
            analyze_port_binding
            analyze_k3s_config
            test_connectivity_levels
            analyze_firewall_detailed
            propose_solutions
            ;;
        "binding")
            analyze_port_binding
            ;;
        "config")
            analyze_k3s_config
            ;;
        "test")
            test_connectivity_levels
            ;;
        "firewall")
            analyze_firewall_detailed
            ;;
        "solutions")
            propose_solutions
            ;;
        "help"|*)
            echo "Usage: $0 {analyze|binding|config|test|firewall|solutions}"
            echo ""
            echo "Commands:"
            echo "  analyze   - Analisi completa (default)"
            echo "  binding   - Solo analisi binding porte"
            echo "  config    - Solo configurazione k3s"
            echo "  test      - Solo test connettività"
            echo "  firewall  - Solo analisi firewall"
            echo "  solutions - Solo proposte soluzioni"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
