#!/bin/bash

# Sync DevOps Configuration Script v3.3
# Sincronizza configurazione DevOps da GitHub
# Condiviso tra FASE 1 e FASE 2

set -e

# Configurazioni
REPO_URL="https://github.com/mcatania72/CRM-System.git"
PROJECT_DIR="$HOME/devops/CRM-System"
DEVOPS_DIR="$HOME/devops-pipeline-fase-2"
LOG_FILE="$HOME/sync-devops-fase-2.log"
BACKUP_PREFIX="devops-pipeline-fase-2_backup"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

echo ""
echo "======================================="
echo "   CRM System - DevOps Sync Script v3.3"
echo "   FASE 2: Containerizzazione Completa"
echo "======================================="

log_info "Inizializzazione sync DevOps config FASE 2..."

# Backup della directory esistente se presente
if [ -d "$DEVOPS_DIR" ]; then
    BACKUP_DIR="${HOME}/${BACKUP_PREFIX}_$(date +%Y%m%d_%H%M%S)"
    log_warning "Directory devops-pipeline-fase-2 esistente. Creando backup..."
    mv "$DEVOPS_DIR" "$BACKUP_DIR"
    log "Backup creato in: $BACKUP_DIR"
fi

# Assicurati di essere nella home directory
cd "$HOME"

# Rimuovi directory progetto esistente se presente
if [ -d "$PROJECT_DIR" ]; then
    log_info "Rimozione directory progetto esistente..."
    
    # Ferma tutti i processi CRM per sync sicuro
    log_info "Fermando processi CRM per sync sicuro..."
    pkill -f "ts-node.*app.ts" 2>/dev/null || true
    pkill -f "npm.*dev" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    # Libera le porte
    lsof -ti:3000 2>/dev/null | xargs -r kill -9 || true
    lsof -ti:3001 2>/dev/null | xargs -r kill -9 || true
    
    sleep 2
    
    # Tentativo 1: rimozione normale
    if ! rm -rf "$PROJECT_DIR" 2>/dev/null; then
        log_warning "Tentativo 1/3 fallito, provo con sudo..."
        
        # Tentativo 2: con sudo
        if ! sudo rm -rf "$PROJECT_DIR" 2>/dev/null; then
            log_warning "Tentativo 2/3 fallito, fixing permissions..."
            
            # Tentativo 3: fix permissions
            sudo chmod -R 777 "$PROJECT_DIR" 2>/dev/null || true
            sudo chown -R "$USER:$USER" "$PROJECT_DIR" 2>/dev/null || true
            
            if ! rm -rf "$PROJECT_DIR" 2>/dev/null; then
                log_error "Impossibile rimuovere directory progetto"
                
                # Ripristina backup se disponibile
                if [ -d "$BACKUP_DIR" ]; then
                    log_warning "Ripristino backup..."
                    mv "$BACKUP_DIR" "$DEVOPS_DIR"
                fi
                exit 1
            fi
        fi
    fi
fi

# Clone del repository
log_info "Clone del repository CRM-System..."
mkdir -p "$(dirname "$PROJECT_DIR")"
cd "$(dirname "$PROJECT_DIR")"

if git clone "$REPO_URL" "$(basename "$PROJECT_DIR")"; then
    log_success "Repository clonato con successo"
else
    log_error "Errore nel clone del repository"
    exit 1
fi

# Copia configurazione DevOps FASE 2
log_info "Copia configurazione DevOps FASE 2..."
if [ -d "$PROJECT_DIR/devops-pipeline-fase-2" ]; then
    cp -r "$PROJECT_DIR/devops-pipeline-fase-2" "$DEVOPS_DIR"
    
    # Rendi eseguibili gli script
    chmod +x "$DEVOPS_DIR"/*.sh 2>/dev/null || true
    
    log_success "Configurazione DevOps FASE 2 copiata"
else
    log_error "Directory devops-pipeline-fase-2 non trovata nel repository"
    exit 1
fi

# Verifica integrità files
log_info "Verifica integrità files..."

verify_file() {
    local file=$1
    local min_size=$2
    local description=$3
    
    if [ -f "$DEVOPS_DIR/$file" ]; then
        local size=$(wc -l < "$DEVOPS_DIR/$file")
        if [ "$size" -gt "$min_size" ]; then
            log_success "✓ $file verificato ($size righe)"
        else
            log_error "✗ $file troppo piccolo ($size righe, minimo $min_size)"
            return 1
        fi
    else
        log_error "✗ $file mancante"
        return 1
    fi
}

# Verifica files essenziali FASE 2
verify_file "prerequisites-docker.sh" 100 "Prerequisites Docker"
verify_file "sync-devops-config.sh" 80 "Sync script"

# Controlla che non ci siano problemi specifici
if ! grep -q "set -e" "$DEVOPS_DIR/sync-devops-config.sh"; then
    log_error "sync-devops-config.sh non ha 'set -e' - possibile corruzione"
    exit 1
fi

# Verifica che sia la versione corretta (FASE 2)
if grep -q "FASE 2" "$DEVOPS_DIR/sync-devops-config.sh"; then
    log_success "✓ sync-devops-config.sh verificato - versione FASE 2"
else
    log_warning "sync-devops-config.sh non contiene riferimenti FASE 2"
fi

# Rimuovi backup se tutto è OK
if [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    log_success "Backup rimosso - sync completato con successo"
fi

# Vai nella directory sincronizzata
cd "$DEVOPS_DIR"

echo ""
echo "======================================="
echo "   SINCRONIZZAZIONE COMPLETATA v3.3"
echo "======================================="
echo "Directory progetto: $PROJECT_DIR"
echo "Directory DevOps FASE 2: $DEVOPS_DIR"
echo "Directory corrente: $(pwd)"
echo "Log file: $LOG_FILE"
echo ""
echo "File sincronizzati (directory corrente):"
ls -la | grep -E "\.(sh|yml|md)$" | awk '{print "  ✓ " $9 ": " $5 " bytes"}'  
echo ""
echo "Prossimi passi (sei già nella directory corretta):"
echo "1. ./prerequisites-docker.sh  # Verifica Docker"
echo "2. ./deploy-containers.sh     # Deploy container"
echo "3. ./test-containers.sh       # Test completi"
echo ""
log_success "Sei ora posizionato nella directory DevOps FASE 2 sincronizzata"

log "DevOps FASE 2 sync completed successfully"