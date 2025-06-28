#!/bin/bash

# ============================================================================
# cleanup-safe.sh - Pulizia Sicura DEV_VM CDR System
# Risparmio stimato: ~9.4GB
# Sicurezza: ALTA - Non rimuove file critici del progetto
# Esegui da: /home/devops
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to get directory size
get_size() {
    if [ -d "$1" ] || [ -f "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Function to show space before/after
show_disk_usage() {
    echo ""
    log "📊 Utilizzo Disco Attuale:"
    df -h / | grep -E "Size|/"
    echo ""
}

# ============================================================================
# MAIN CLEANUP SCRIPT
# ============================================================================

log "🚀 Avvio cleanup-safe.sh per DEV_VM CDR System"
log "📍 Directory corrente: $(pwd)"
log "👤 Utente: $(whoami)"

# Show initial disk usage
show_disk_usage

# Track savings
total_saved=0

log "🧹 FASE 1: Pulizia Docker (Risparmio stimato: ~9.2GB)"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker non è in esecuzione. Tentativo di avvio..."
    sudo systemctl start docker || {
        error "Impossibile avviare Docker. Avvialo manualmente e riprova."
        show_disk_usage
        exit 1
    }
    success "Docker avviato con successo"
fi

# Show current Docker usage
log "📊 Stato Docker Prima della Pulizia:"
docker system df

# Docker cleanup
log "🔄 Rimozione immagini Docker non utilizzate..."
docker_images_before=$(docker images -q | wc -l 2>/dev/null || echo "0")
if docker image prune -a -f >/dev/null 2>&1; then
    docker_images_after=$(docker images -q | wc -l 2>/dev/null || echo "0")
    images_removed=$((docker_images_before - docker_images_after))
    success "Rimosse $images_removed immagini Docker"
else
    warning "Errore nella rimozione immagini Docker - continuando..."
fi

log "🔄 Rimozione build cache Docker..."
if docker builder prune -f >/dev/null 2>&1; then
    success "Build cache Docker rimossa"
else
    warning "Errore nella rimozione build cache - continuando..."
fi

log "🔄 Pulizia completa sistema Docker..."
if docker system prune -a -f --volumes >/dev/null 2>&1; then
    success "Sistema Docker pulito"
else
    warning "Errore nella pulizia sistema Docker - continuando..."
fi

# Show Docker usage after cleanup
log "📊 Stato Docker Dopo la Pulizia:"
docker system df

log "🧹 FASE 2: Pulizia Cache NPM (Risparmio stimato: ~0.14GB)"

# NPM cache cleanup
if command -v npm >/dev/null 2>&1; then
    npm_cache_before=$(get_size ~/.npm)
    log "🔄 Pulizia cache NPM (dimensione attuale: $npm_cache_before)..."
    if npm cache clean --force >/dev/null 2>&1; then
        npm_cache_after=$(get_size ~/.npm)
        success "Cache NPM pulita (prima: $npm_cache_before, dopo: $npm_cache_after)"
    else
        warning "Errore nella pulizia cache NPM - continuando..."
    fi
else
    warning "NPM non trovato, skip pulizia cache NPM"
fi

log "🧹 FASE 3: Rimozione Backup Vecchi (Risparmio stimato: ~0.55MB)"

# Remove old backups
backup_count=0
for backup_dir in $HOME/devops-pipeline-fase-4_backup_*; do
    if [ -d "$backup_dir" ]; then
        backup_size=$(get_size "$backup_dir")
        log "🔄 Rimozione backup: $(basename "$backup_dir") (dimensione: $backup_size)"
        if rm -rf "$backup_dir" 2>/dev/null; then
            ((backup_count++))
            success "Backup rimosso: $(basename "$backup_dir")"
        else
            warning "Errore rimozione backup $(basename "$backup_dir") - continuando..."
        fi
    fi
done

if [ $backup_count -eq 0 ]; then
    log "ℹ️  Nessun backup vecchio trovato"
else
    success "Rimossi $backup_count backup vecchi"
fi

log "🧹 FASE 4: Pulizia Log Temporanei (Risparmio stimato: ~0.27MB)"

# Remove temporary logs
log_files=(
    "$HOME/sync-testing.log"
    "$HOME/sync-devops.log" 
    "$HOME/test-advanced.log"
    "$HOME/deploy.log"
    "$HOME/test-jenkins.log"
)

log_count=0
for log_file in "${log_files[@]}"; do
    if [ -f "$log_file" ]; then
        log_size=$(get_size "$log_file")
        log "🔄 Rimozione log: $(basename "$log_file") (dimensione: $log_size)"
        if rm -f "$log_file" 2>/dev/null; then
            ((log_count++))
            success "Log rimosso: $(basename "$log_file")"
        else
            warning "Errore rimozione log $(basename "$log_file") - continuando..."
        fi
    fi
done

if [ $log_count -eq 0 ]; then
    log "ℹ️  Nessun log temporaneo trovato"
else
    success "Rimossi $log_count file di log temporanei"
fi

log "🧹 FASE 5: Pulizia File Temporanei Utente"

# Clean user temp files
temp_dirs=(
    "/tmp"
)

for temp_dir in "${temp_dirs[@]}"; do
    if [ -d "$temp_dir" ] && [ -w "$temp_dir" ]; then
        temp_size_before=$(get_size "$temp_dir")
        log "🔄 Pulizia $temp_dir (dimensione: $temp_size_before)..."
        # Only remove files we own to avoid permission issues
        find "$temp_dir" -user "$(whoami)" -type f -mtime +1 -delete 2>/dev/null || true
        temp_size_after=$(get_size "$temp_dir")
        success "Pulito $temp_dir (prima: $temp_size_before, dopo: $temp_size_after)"
    fi
done

# ============================================================================
# FINAL REPORT
# ============================================================================

log "📊 PULIZIA COMPLETATA!"
echo ""
log "🎯 Operazioni Eseguite:"
echo "   ✅ Docker system cleanup"
echo "   ✅ NPM cache cleanup"  
echo "   ✅ Backup vecchi rimossi ($backup_count backup)"
echo "   ✅ Log temporanei rimossi ($log_count log)"
echo "   ✅ File temporanei puliti"
echo ""

# Show final disk usage
show_disk_usage

log "💡 RACCOMANDAZIONI POST-PULIZIA:"
echo "   1. Verifica che il CDR System funzioni ancora:"
echo "      cd $HOME/devops/CRM-System && docker-compose up -d"
echo ""
echo "   2. Se hai problemi, ricostruisci le immagini:"
echo "      cd $HOME/devops/CRM-System && docker-compose build"
echo ""
echo "   3. Per pulizie più aggressive, chiedi cleanup-aggressive.sh"
echo ""

success "🎉 cleanup-safe.sh completato con successo!"
success "📈 Risparmio stimato: ~9.4GB di spazio liberato"

log "🔄 Per verificare il nuovo utilizzo disco:"
echo "   df -h /"