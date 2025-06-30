#!/bin/bash

# ================================
# AWS MONITORING - CRM SYSTEM
# Monitoring e ottimizzazione per EC2 t2.micro
# ================================

set -euo pipefail

# Configurazione
AWS_REGION="us-east-1"
INSTANCE_NAME="crm-system-instance"
NAMESPACE="crm-system"

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

echo "=== 📊 AWS MONITORING - CRM SYSTEM ==="
echo "Timestamp: $(date)"
echo ""

# ================================
# FUNZIONE: OTTIENI INFO ISTANZA
# ================================
get_instance_info() {
    log_info "🔍 Ricerca istanza AWS..."
    
    local instance_info=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
        --output text 2>/dev/null || echo "None None None")
    
    read -r INSTANCE_ID PUBLIC_IP PRIVATE_IP <<< "$instance_info"
    
    if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ]; then
        log_error "❌ Nessuna istanza CRM trovata"
        exit 1
    fi
    
    log_success "✅ Istanza trovata: $INSTANCE_ID ($PUBLIC_IP)"
}

# ================================
# FUNZIONE: MONITORING RISORSE
# ================================
monitor_resources() {
    log_info "📊 Monitoring risorse sistema..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🖥️ SYSTEM OVERVIEW ==="
echo "Uptime:"
uptime

echo ""
echo "=== 💾 MEMORY USAGE ==="
free -h
echo ""
echo "Memory Pressure:"
if [ -f /proc/pressure/memory ]; then
    cat /proc/pressure/memory
else
    echo "Pressure stats not available"
fi

echo ""
echo "=== 🔄 CPU USAGE ==="
echo "Current CPU usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1

echo ""
echo "Load Average:"
cat /proc/loadavg

echo ""
echo "=== 💿 DISK USAGE ==="
df -h
echo ""
echo "Disk I/O:"
iostat -x 1 1 2>/dev/null | tail -n +4 || echo "iostat not available"

echo ""
echo "=== 🔗 NETWORK ==="
echo "Network connections:"
ss -tuln | grep -E ":30002|:30003|:22|:80|:443" || echo "No active connections on monitored ports"

echo ""
echo "=== 🐳 DOCKER RESOURCES ==="
echo "Docker stats (1 sample):"
timeout 5 docker stats --no-stream 2>/dev/null | head -10 || echo "Docker stats not available"

echo ""
echo "=== ☸️ KUBERNETES RESOURCES ==="
echo "Pod resource usage:"
sudo k3s kubectl top pods -n crm-system 2>/dev/null || echo "Metrics not available"

echo ""
echo "Node resource usage:"
sudo k3s kubectl top nodes 2>/dev/null || echo "Metrics not available"

echo ""
echo "=== 🔍 POD STATUS ==="
sudo k3s kubectl get pods -n crm-system -o wide

echo ""
echo "=== 📝 RECENT LOGS ==="
echo "System logs (last 10):"
sudo journalctl --since "5 minutes ago" --no-pager | tail -10

echo ""
echo "k3s logs (last 5):"
sudo journalctl -u k3s --since "5 minutes ago" --no-pager | tail -5
EOF

    log_success "✅ Monitoring risorse completato"
}

# ================================
# FUNZIONE: PERFORMANCE ANALYSIS
# ================================
analyze_performance() {
    log_info "⚡ Analisi performance sistema..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🎯 PERFORMANCE ANALYSIS ==="

echo "=== Memory Analysis ==="
echo "Available memory:"
free -m | awk 'NR==2{printf "Used: %d MB (%.2f%%), Available: %d MB (%.2f%%)\n", $3,$3*100/$2, $7,$7*100/$2 }'

echo ""
echo "Memory by process (top 10):"
ps aux --sort=-%mem | head -11

echo ""
echo "=== CPU Analysis ==="
echo "CPU usage by process (top 10):"
ps aux --sort=-%cpu | head -11

echo ""
echo "=== Disk Analysis ==="
echo "Disk usage:"
df -h / | tail -1 | awk '{print "Used: " $3 " (" $5 "), Available: " $4}'

echo ""
echo "Largest directories:"
du -h /var/lib/docker 2>/dev/null | tail -1 || echo "Docker data: N/A"
du -h /var/lib/rancher 2>/dev/null | tail -1 || echo "k3s data: N/A"

echo ""
echo "=== Container Analysis ==="
echo "Container resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -10 || echo "Docker stats not available"

echo ""
echo "=== k3s Analysis ==="
echo "k3s system pods:"
sudo k3s kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory"

echo ""
echo "Application pods:"
sudo k3s kubectl get pods -n crm-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory"
EOF

    log_success "✅ Analisi performance completata"
}

# ================================
# FUNZIONE: HEALTH CHECKS
# ================================
health_checks() {
    log_info "🏥 Health checks applicazione..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🏥 APPLICATION HEALTH CHECKS ==="

echo "=== Service Connectivity ==="
echo "🧪 Frontend Health Check:"
if curl -s --connect-timeout 5 http://localhost:30002 > /dev/null; then
    echo "✅ Frontend OK"
else
    echo "❌ Frontend FAIL"
fi

echo ""
echo "🧪 Backend Health Check:"
if curl -s --connect-timeout 5 http://localhost:30003/api/health > /dev/null; then
    echo "✅ Backend OK"
    echo "Backend Response:"
    curl -s http://localhost:30003/api/health | head -3
else
    echo "❌ Backend FAIL"
fi

echo ""
echo "=== Database Connectivity ==="
echo "🗄️ PostgreSQL Connection:"
sudo k3s kubectl exec -n crm-system deployment/postgres -- pg_isready -U crm_user -d crm_db 2>/dev/null && echo "✅ Database OK" || echo "❌ Database FAIL"

echo ""
echo "=== Pod Health Status ==="
sudo k3s kubectl get pods -n crm-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount"

echo ""
echo "=== Resource Quotas ==="
echo "Current resource usage vs limits:"
sudo k3s kubectl describe nodes | grep -A 5 "Allocated resources:" || echo "Resource info not available"
EOF

    log_success "✅ Health checks completati"
}

# ================================
# FUNZIONE: OPTIMIZE SYSTEM
# ================================
optimize_system() {
    log_info "⚡ Ottimizzazione sistema per performance..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🔧 SYSTEM OPTIMIZATION ==="

echo "=== Memory Optimization ==="
echo "Current memory status:"
free -m

# Cleanup system caches
echo "🧹 Cleaning system caches..."
sudo sync
sudo sysctl -w vm.drop_caches=3

# Docker cleanup
echo "🐳 Docker cleanup..."
docker system prune -f 2>/dev/null || echo "Docker cleanup failed"

# Swap tuning
echo "💿 Swap tuning..."
sudo sysctl vm.swappiness=10
sudo sysctl vm.vfs_cache_pressure=50

echo ""
echo "=== k3s Optimization ==="
echo "🔄 Restarting k3s components if needed..."

# Check if any pods are in bad state
PROBLEM_PODS=$(sudo k3s kubectl get pods -n crm-system --field-selector=status.phase!=Running -o name 2>/dev/null | wc -l)
if [ "$PROBLEM_PODS" -gt 0 ]; then
    echo "🔄 Restarting problematic pods..."
    sudo k3s kubectl delete pods -n crm-system --field-selector=status.phase!=Running --force --grace-period=0 2>/dev/null || true
fi

echo ""
echo "=== Container Optimization ==="
echo "🔄 Container resource optimization..."

# Optimize PostgreSQL if running
if sudo k3s kubectl get pod -n crm-system | grep postgres | grep Running > /dev/null; then
    echo "🗄️ PostgreSQL optimization..."
    sudo k3s kubectl exec -n crm-system deployment/postgres -- psql -U crm_user -d crm_db -c "VACUUM ANALYZE;" 2>/dev/null || echo "PostgreSQL optimization failed"
fi

echo ""
echo "Memory status after optimization:"
free -m
EOF

    log_success "✅ Ottimizzazione sistema completata"
}

# ================================
# FUNZIONE: ALERTS SETUP
# ================================
setup_alerts() {
    log_info "🚨 Setup alerts per resource monitoring..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 🚨 SETTING UP ALERTS ==="

# Crea script di monitoring
cat > /tmp/resource_monitor.sh << 'MONITOR_EOF'
#!/bin/bash

# Thresholds per t2.micro
MEMORY_THRESHOLD=85  # 85% memory usage
CPU_THRESHOLD=80     # 80% CPU usage
DISK_THRESHOLD=85    # 85% disk usage

# Check memory
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ]; then
    echo "🚨 ALERT: Memory usage at ${MEMORY_USAGE}% (threshold: ${MEMORY_THRESHOLD}%)"
    logger "CRM-ALERT: High memory usage: ${MEMORY_USAGE}%"
fi

# Check CPU (5 minute average)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | cut -d',' -f1)
CPU_USAGE=$(echo "$CPU_LOAD * 100" | bc 2>/dev/null || echo "0")
if [ "${CPU_USAGE%.*}" -gt "$CPU_THRESHOLD" ] 2>/dev/null; then
    echo "🚨 ALERT: CPU load at ${CPU_LOAD} (threshold: ${CPU_THRESHOLD}%)"
    logger "CRM-ALERT: High CPU load: ${CPU_LOAD}"
fi

# Check disk
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "🚨 ALERT: Disk usage at ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    logger "CRM-ALERT: High disk usage: ${DISK_USAGE}%"
fi

# Check pod status
FAILED_PODS=$(sudo k3s kubectl get pods -n crm-system --field-selector=status.phase!=Running -o name 2>/dev/null | wc -l)
if [ "$FAILED_PODS" -gt 0 ]; then
    echo "🚨 ALERT: $FAILED_PODS pod(s) not running in crm-system namespace"
    logger "CRM-ALERT: Failed pods: $FAILED_PODS"
fi
MONITOR_EOF

chmod +x /tmp/resource_monitor.sh

# Test the monitor script
echo "🧪 Testing monitoring script..."
/tmp/resource_monitor.sh

# Setup cron job for regular monitoring
echo "⏰ Setting up cron job for monitoring..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /tmp/resource_monitor.sh") | crontab -

echo "✅ Alerts setup completed"
echo "Monitor script will run every 5 minutes"
echo "Check logs with: journalctl -f | grep CRM-ALERT"
EOF

    log_success "✅ Alerts configurati"
}

# ================================
# FUNZIONE: BACKUP DATABASE
# ================================
backup_database() {
    log_info "💾 Backup database PostgreSQL..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << 'EOF'
echo "=== 💾 DATABASE BACKUP ==="

# Create backup directory
mkdir -p /home/ubuntu/backups
cd /home/ubuntu/backups

# Get current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="crm_backup_${TIMESTAMP}.sql"

echo "🗄️ Creating database backup..."
sudo k3s kubectl exec -n crm-system deployment/postgres -- pg_dump -U crm_user crm_db > "$BACKUP_FILE" 2>/dev/null

if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    echo "✅ Backup created: $BACKUP_FILE"
    echo "📊 Backup size: $(du -h $BACKUP_FILE | cut -f1)"
    
    # Compress backup
    echo "🗜️ Compressing backup..."
    gzip "$BACKUP_FILE"
    echo "📊 Compressed size: $(du -h ${BACKUP_FILE}.gz | cut -f1)"
    
    # Cleanup old backups (keep last 5)
    echo "🧹 Cleaning old backups..."
    ls -t crm_backup_*.sql.gz 2>/dev/null | tail -n +6 | xargs rm -f
    
    echo "📁 Available backups:"
    ls -lh crm_backup_*.sql.gz 2>/dev/null || echo "No backups found"
else
    echo "❌ Backup failed"
    exit 1
fi
EOF

    log_success "✅ Database backup completato"
}

# ================================
# FUNZIONE: RESTORE DATABASE
# ================================
restore_database() {
    local backup_file=${1:-""}
    
    if [ -z "$backup_file" ]; then
        log_error "❌ Specificare file di backup"
        echo "Usage: $0 restore-database <backup_file.sql.gz>"
        return 1
    fi
    
    log_info "🔄 Restore database da backup..."
    
    ssh -i crm-key-pair.pem ubuntu@"$PUBLIC_IP" << EOF
echo "=== 🔄 DATABASE RESTORE ==="

cd /home/ubuntu/backups

if [ ! -f "$backup_file" ]; then
    echo "❌ File backup non trovato: $backup_file"
    echo "📁 Backup disponibili:"
    ls -lh crm_backup_*.sql.gz 2>/dev/null || echo "Nessun backup trovato"
    exit 1
fi

echo "📂 Restoring from: $backup_file"

# Decompress if needed
if [[ "$backup_file" == *.gz ]]; then
    echo "🗜️ Decompressing backup..."
    gunzip -k "$backup_file"
    SQL_FILE="\${backup_file%.gz}"
else
    SQL_FILE="$backup_file"
fi

# Restore database
echo "🗄️ Restoring database..."
sudo k3s kubectl exec -i -n crm-system deployment/postgres -- psql -U crm_user crm_db < "\$SQL_FILE"

if [ \$? -eq 0 ]; then
    echo "✅ Database restore completed"
    
    # Cleanup decompressed file if it was compressed
    if [[ "$backup_file" == *.gz ]]; then
        rm -f "\$SQL_FILE"
    fi
else
    echo "❌ Database restore failed"
    exit 1
fi
EOF

    log_success "✅ Database restore completato"
}

# ================================
# MAIN EXECUTION
# ================================
main() {
    case "${1:-help}" in
        "resources")
            get_instance_info
            monitor_resources
            ;;
        "performance")
            get_instance_info
            analyze_performance
            ;;
        "health")
            get_instance_info
            health_checks
            ;;
        "optimize")
            get_instance_info
            optimize_system
            ;;
        "alerts")
            get_instance_info
            setup_alerts
            ;;
        "backup-database")
            get_instance_info
            backup_database
            ;;
        "restore-database")
            get_instance_info
            restore_database "${2:-}"
            ;;
        "full-status")
            get_instance_info
            monitor_resources
            analyze_performance
            health_checks
            ;;
        "help"|*)
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  resources           - Monitor system resources"
            echo "  performance         - Analyze system performance"
            echo "  health             - Application health checks"
            echo "  optimize           - Optimize system for performance"
            echo "  alerts             - Setup resource monitoring alerts"
            echo "  backup-database    - Backup PostgreSQL database"
            echo "  restore-database   - Restore database from backup"
            echo "  full-status        - Complete system overview"
            echo ""
            echo "Examples:"
            echo "  $0 resources                           # Monitor resources"
            echo "  $0 performance                         # Performance analysis"
            echo "  $0 health                              # Health checks"
            echo "  $0 optimize                            # Optimize system"
            echo "  $0 backup-database                     # Create DB backup"
            echo "  $0 restore-database crm_backup_*.sql.gz # Restore DB"
            echo "  $0 full-status                         # Complete overview"
            exit 1
            ;;
    esac
}

# Esecuzione
main "$@"
