#!/bin/bash

# AWS Monitoring Script per Docker Compose - t2.micro ottimizzato
# Monitoring, alerting e ottimizzazioni specifiche per risorse limitate

set -euo pipefail

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/aws-monitoring.log"
CRM_DIR="$HOME/crm-docker"

# Soglie di alert per t2.micro
MEMORY_ALERT_THRESHOLD=85    # 85% memoria utilizzata
DISK_ALERT_THRESHOLD=80      # 80% disco utilizzato
SWAP_ALERT_THRESHOLD=50      # 50% swap utilizzato
LOAD_ALERT_THRESHOLD=2.0     # Load average > 2.0

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

alert() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ALERT: $1${NC}" | tee -a "$LOG_FILE"
}

# Ottieni info sistema AWS
get_aws_info() {
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
        echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
        echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
        echo "Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
        echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    else
        echo "Not running on AWS EC2 or metadata service unavailable"
    fi
}

# Monitor memoria sistema
check_memory() {
    local total_mem used_mem available_mem mem_percentage
    local swap_total swap_used swap_percentage
    
    # Memoria RAM
    total_mem=$(free -m | awk 'NR==2{print $2}')
    used_mem=$(free -m | awk 'NR==2{print $3}')
    available_mem=$(free -m | awk 'NR==2{print $7}')
    mem_percentage=$(awk "BEGIN {printf \"%.1f\", ($used_mem/$total_mem)*100}")
    
    # Swap
    swap_total=$(free -m | awk 'NR==3{print $2}')
    swap_used=$(free -m | awk 'NR==3{print $3}')
    
    if [ "$swap_total" -gt 0 ]; then
        swap_percentage=$(awk "BEGIN {printf \"%.1f\", ($swap_used/$swap_total)*100}")
    else
        swap_percentage=0
    fi
    
    echo "=== MEMORY STATUS ==="
    echo "RAM: ${used_mem}MB/${total_mem}MB (${mem_percentage}% used, ${available_mem}MB available)"
    echo "Swap: ${swap_used}MB/${swap_total}MB (${swap_percentage}% used)"
    
    # Alert se memoria alta
    if (( $(echo "$mem_percentage > $MEMORY_ALERT_THRESHOLD" | bc -l) )); then
        alert "High memory usage: ${mem_percentage}%"
    fi
    
    # Alert se swap alta
    if (( $(echo "$swap_percentage > $SWAP_ALERT_THRESHOLD" | bc -l) )); then
        alert "High swap usage: ${swap_percentage}%"
    fi
    
    # Alert se poca memoria disponibile
    if [ "$available_mem" -lt 100 ]; then
        alert "Low available memory: ${available_mem}MB"
    fi
}

# Monitor CPU e load
check_cpu() {
    local load_1min load_5min load_15min cpu_cores
    
    read load_1min load_5min load_15min _ < /proc/loadavg
    cpu_cores=$(nproc)
    
    echo "=== CPU STATUS ==="
    echo "Load Average: ${load_1min} (1m), ${load_5min} (5m), ${load_15min} (15m)"
    echo "CPU Cores: ${cpu_cores}"
    echo "Load per Core: $(awk "BEGIN {printf \"%.2f\", $load_1min/$cpu_cores}")"
    
    # Alert se load troppo alto
    if (( $(echo "$load_1min > $LOAD_ALERT_THRESHOLD" | bc -l) )); then
        alert "High load average: ${load_1min}"
    fi
}

# Monitor spazio disco
check_disk() {
    local disk_usage disk_percentage
    
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    echo "=== DISK STATUS ==="
    df -h /
    
    # Alert se disco pieno
    if [ "$disk_usage" -gt "$DISK_ALERT_THRESHOLD" ]; then
        alert "High disk usage: ${disk_usage}%"
    fi
    
    # Mostra usage Docker
    echo ""
    echo "Docker Disk Usage:"
    docker system df 2>/dev/null || echo "Docker not running"
}

# Monitor network
check_network() {
    echo "=== NETWORK STATUS ==="
    
    # Connessioni attive
    local connections
    connections=$(ss -tun | wc -l)
    echo "Active connections: $connections"
    
    # Test connettività esterna
    if curl -s --max-time 3 http://checkip.amazonaws.com > /dev/null; then
        echo "External connectivity: OK"
    else
        warn "External connectivity issues"
    fi
    
    # Porte in ascolto
    echo "Listening ports:"
    ss -tlnp | grep -E ':(22|80|443|30002|30003|5432)' || echo "No relevant ports found"
}

# Monitor servizi Docker
check_docker_services() {
    echo "=== DOCKER SERVICES STATUS ==="
    
    if ! command -v docker &> /dev/null; then
        warn "Docker not installed"
        return
    fi
    
    if ! docker info > /dev/null 2>&1; then
        error "Docker daemon not running"
        return
    fi
    
    # Status Docker Compose
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        
        echo "Docker Compose Services:"
        docker-compose ps 2>/dev/null || echo "No docker-compose.yml found"
        
        echo ""
        echo "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || echo "No running containers"
        
        # Health checks
        echo ""
        echo "Service Health Checks:"
        check_service_health "postgres" "5432"
        check_service_health "backend" "30003"
        check_service_health "frontend" "30002"
    else
        warn "CRM directory not found: $CRM_DIR"
    fi
}

# Check specifico health di un servizio
check_service_health() {
    local service_name=$1
    local port=$2
    
    if docker-compose ps "$service_name" 2>/dev/null | grep -q "Up"; then
        if nc -z localhost "$port" 2>/dev/null; then
            echo "✅ $service_name: Running and accessible on port $port"
        else
            warn "$service_name: Running but port $port not accessible"
        fi
    else
        warn "$service_name: Not running"
    fi
}

# Test endpoint applicazione
test_application_endpoints() {
    echo "=== APPLICATION ENDPOINTS TEST ==="
    
    # Test frontend
    if curl -s --max-time 5 http://localhost:30002 > /dev/null; then
        echo "✅ Frontend (30002): OK"
    else
        warn "Frontend (30002): Failed"
    fi
    
    # Test backend health
    if curl -s --max-time 5 http://localhost:30003/api/health | grep -q "healthy"; then
        echo "✅ Backend Health (30003): OK"
    else
        warn "Backend Health (30003): Failed"
    fi
    
    # Test database via backend
    if curl -s --max-time 5 http://localhost:30003/api/companies > /dev/null; then
        echo "✅ Database connectivity: OK"
    else
        warn "Database connectivity: Failed"
    fi
}

# Monitor log applicazione per errori
check_application_logs() {
    echo "=== APPLICATION LOGS ANALYSIS ==="
    
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        
        # Ultimi errori PostgreSQL
        echo "Recent PostgreSQL errors:"
        docker-compose logs --tail=50 postgres 2>/dev/null | grep -i error | tail -5 || echo "No errors found"
        
        echo ""
        echo "Recent Backend errors:"
        docker-compose logs --tail=50 backend 2>/dev/null | grep -i error | tail -5 || echo "No errors found"
        
        echo ""
        echo "Recent Frontend errors:"
        docker-compose logs --tail=50 frontend 2>/dev/null | grep -i error | tail -5 || echo "No errors found"
    fi
}

# Ottimizzazioni automatiche
auto_optimize() {
    log "🔧 Running automatic optimizations..."
    
    # Pulisci Docker se uso disco > 70%
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 70 ]; then
        log "High disk usage ($disk_usage%), cleaning Docker..."
        docker system prune -f > /dev/null 2>&1 || true
        docker volume prune -f > /dev/null 2>&1 || true
        log "Docker cleanup completed"
    fi
    
    # Pulisci log di sistema se necessario
    if [ "$disk_usage" -gt 75 ]; then
        log "Cleaning system logs..."
        sudo journalctl --vacuum-time=3d > /dev/null 2>&1 || true
        log "System log cleanup completed"
    fi
    
    # Restart container se memoria troppo alta
    local mem_percentage
    mem_percentage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    
    if (( $(echo "$mem_percentage > 90" | bc -l) )); then
        warn "Very high memory usage ($mem_percentage%), considering container restart..."
        # Uncomment per restart automatico
        # restart_heavy_containers
    fi
}

# Restart container pesanti
restart_heavy_containers() {
    log "🔄 Restarting heavy containers to free memory..."
    
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        
        # Restart backend (spesso consuma più memoria)
        docker-compose restart backend > /dev/null 2>&1 || true
        sleep 10
        
        log "Container restart completed"
    fi
}

# Backup automatico se necessario
auto_backup() {
    local last_backup_time current_time
    
    # Controlla se ultimo backup > 24 ore fa
    if [ -f "$HOME/crm-backups/.last_backup" ]; then
        last_backup_time=$(cat "$HOME/crm-backups/.last_backup")
        current_time=$(date +%s)
        
        # Se ultimo backup > 24 ore fa (86400 secondi)
        if [ $((current_time - last_backup_time)) -gt 86400 ]; then
            log "📦 Running automatic backup (last backup > 24h ago)..."
            backup_database
        fi
    else
        log "📦 Running first automatic backup..."
        backup_database
    fi
}

# Backup database
backup_database() {
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        
        local backup_dir="$HOME/crm-backups"
        mkdir -p "$backup_dir"
        
        local backup_file="$backup_dir/auto-backup-$(date +%Y%m%d_%H%M%S).sql"
        
        if docker-compose exec -T postgres pg_dump -U crm_user crm_db > "$backup_file" 2>/dev/null; then
            log "✅ Database backup completed: $backup_file"
            echo "$(date +%s)" > "$backup_dir/.last_backup"
            
            # Comprimi backup vecchi di più di 1 giorno
            find "$backup_dir" -name "*.sql" -mtime +1 -exec gzip {} \; 2>/dev/null || true
            
            # Rimuovi backup compressi più vecchi di 7 giorni
            find "$backup_dir" -name "*.sql.gz" -mtime +7 -delete 2>/dev/null || true
        else
            error "Database backup failed"
        fi
    fi
}

# Alert email/notifica (placeholder)
send_alert() {
    local message=$1
    
    # Log locale per ora
    echo "[ALERT] $message" >> "$HOME/alerts.log"
    
    # Qui potresti aggiungere:
    # - Email via sendmail
    # - Webhook a Slack/Discord
    # - SNS notification AWS
    # - etc.
}

# Report completo
generate_report() {
    echo "=================================="
    echo "=== AWS CRM MONITORING REPORT ==="
    echo "=================================="
    echo "Generated: $(date)"
    echo ""
    
    get_aws_info
    echo ""
    
    check_memory
    echo ""
    
    check_cpu
    echo ""
    
    check_disk
    echo ""
    
    check_network
    echo ""
    
    check_docker_services
    echo ""
    
    test_application_endpoints
    echo ""
    
    check_application_logs
    echo ""
    
    echo "=================================="
    echo "Report completed: $(date)"
    echo "=================================="
}

# Monitor in tempo reale
live_monitor() {
    log "🔄 Starting live monitoring (Press Ctrl+C to stop)..."
    
    while true; do
        clear
        echo "🚀 CRM Live Monitor - $(date)"
        echo "=================================="
        
        # Info rapide
        echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2" ("$3/$2*100"%)"}')"
        echo "Load: $(cat /proc/loadavg | awk '{print $1}')"
        echo "Disk: $(df / | awk 'NR==2{print $5}')"
        
        echo ""
        echo "=== Docker Containers ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "No containers running"
        
        echo ""
        echo "=== Service Status ==="
        if [ -d "$CRM_DIR" ]; then
            cd "$CRM_DIR"
            docker-compose ps 2>/dev/null | head -10
        else
            echo "CRM not deployed"
        fi
        
        echo ""
        echo "Press Ctrl+C to stop..."
        
        sleep 5
    done
}

# Alert check rapido
quick_check() {
    local alerts=0
    
    # Check memoria
    local mem_percentage
    mem_percentage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$mem_percentage" -gt "$MEMORY_ALERT_THRESHOLD" ]; then
        alert "High memory: ${mem_percentage}%"
        ((alerts++))
    fi
    
    # Check disco
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$DISK_ALERT_THRESHOLD" ]; then
        alert "High disk: ${disk_usage}%"
        ((alerts++))
    fi
    
    # Check load
    local load_1min
    load_1min=$(cat /proc/loadavg | awk '{print $1}')
    if (( $(echo "$load_1min > $LOAD_ALERT_THRESHOLD" | bc -l) )); then
        alert "High load: ${load_1min}"
        ((alerts++))
    fi
    
    # Check servizi
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        local running_services
        running_services=$(docker-compose ps | grep -c "Up" 2>/dev/null || echo "0")
        if [ "$running_services" -lt 3 ]; then
            alert "Services not running: $running_services/3"
            ((alerts++))
        fi
    fi
    
    if [ "$alerts" -eq 0 ]; then
        log "✅ Quick check: All systems OK"
    else
        warn "⚠️ Quick check: $alerts alerts found"
    fi
    
    return $alerts
}

# Menu principale
show_menu() {
    echo ""
    echo "🔍 ========== AWS CRM Monitoring =========="
    echo "1.  report      - Complete system report"
    echo "2.  quick       - Quick health check"
    echo "3.  live        - Live monitoring"
    echo "4.  optimize    - Run optimizations"
    echo "5.  backup      - Manual backup"
    echo "6.  logs        - View application logs"
    echo "7.  alerts      - Check for alerts"
    echo "8.  docker      - Docker resource usage"
    echo "9.  endpoints   - Test API endpoints"
    echo "10. cleanup     - Clean up resources"
    echo "==========================================="
}

# Docker resource usage dettagliato
docker_resources() {
    echo "=== DOCKER RESOURCE USAGE ==="
    
    if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
        echo "Docker System Info:"
        docker system df
        
        echo ""
        echo "Container Details:"
        docker stats --no-stream
        
        echo ""
        echo "Image Sizes:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
        
        echo ""
        echo "Volume Usage:"
        docker volume ls -q | xargs -r docker volume inspect | jq -r '.[] | "\(.Name): \(.Mountpoint)"' 2>/dev/null || docker volume ls
    else
        warn "Docker not available"
    fi
}

# Cleanup risorse
cleanup_resources() {
    log "🧹 Cleaning up system resources..."
    
    # Docker cleanup
    if command -v docker &> /dev/null; then
        log "Cleaning Docker resources..."
        docker system prune -f > /dev/null 2>&1 || true
        docker volume prune -f > /dev/null 2>&1 || true
        docker image prune -f > /dev/null 2>&1 || true
    fi
    
    # Log cleanup
    log "Cleaning system logs..."
    sudo journalctl --vacuum-time=7d > /dev/null 2>&1 || true
    
    # Temporary files
    log "Cleaning temporary files..."
    sudo find /tmp -type f -mtime +7 -delete 2>/dev/null || true
    
    # Package cache
    log "Cleaning package cache..."
    sudo apt autoremove -y > /dev/null 2>&1 || true
    sudo apt autoclean > /dev/null 2>&1 || true
    
    log "✅ Cleanup completed"
}

# Main function
main() {
    case "${1:-menu}" in
        "report")
            generate_report
            ;;
        "quick")
            quick_check
            ;;
        "live")
            live_monitor
            ;;
        "optimize")
            auto_optimize
            ;;
        "backup")
            backup_database
            ;;
        "logs")
            check_application_logs
            ;;
        "alerts")
            quick_check
            ;;
        "docker")
            docker_resources
            ;;
        "endpoints")
            test_application_endpoints
            ;;
        "cleanup")
            cleanup_resources
            ;;
        "auto")
            # Modalità automatica per cron
            quick_check
            auto_optimize
            auto_backup
            ;;
        "menu"|*)
            show_menu
            echo ""
            echo "Usage: $0 {report|quick|live|optimize|backup|logs|alerts|docker|endpoints|cleanup|auto}"
            ;;
    esac
}

# Installa bc se non presente (per calcoli floating point)
if ! command -v bc &> /dev/null; then
    sudo apt install -y bc > /dev/null 2>&1 || true
fi

# Esegui main
main "$@"
