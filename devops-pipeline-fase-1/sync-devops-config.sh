#!/bin/bash

# sync-devops-config.sh v3.3
# Script per sincronizzare la configurazione DevOps dalla repository GitHub
# Fix: aggiunto cd esplicito alla fine per posizionare l'utente nella directory corretta

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
REPO_URL="https://github.com/mcatania72/CRM-System.git"
PROJECT_DIR="$HOME/devops/CRM-System"
DEVOPS_CONFIG_DIR="$HOME/devops-pipeline-fase-1"
LOG_FILE="$HOME/sync-devops.log"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funzione per output colorato
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[INFO]${NC} $message"
    log "$message"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

# Funzione per gestire il cambio directory sicuro
safe_cd_home() {
    print_status $BLUE "Passaggio a directory home per sync sicuro..."
    
    # Forza il cambio alla home directory
    cd "$HOME"
    
    # Verifica che siamo nella home
    if [ "$(pwd)" != "$HOME" ]; then
        print_error "Impossibile cambiare directory a: $HOME"
        exit 1
    fi
    
    print_success "Directory di lavoro: $(pwd)"
}

# Funzione per fermare tutti i processi CRM
stop_crm_processes() {
    print_status $YELLOW "Fermando processi CRM per sync sicuro..."
    
    # Ferma processi Node.js relativi al CRM
    local backend_pids=$(pgrep -f "ts-node.*app.ts" 2>/dev/null || true)
    local frontend_pids=$(pgrep -f "vite" 2>/dev/null || true)
    local node_pids=$(pgrep -f "node.*CRM-System" 2>/dev/null || true)
    
    # Ferma backend
    if [ -n "$backend_pids" ]; then
        print_status $YELLOW "Fermando processi backend: $backend_pids"
        echo "$backend_pids" | xargs -r kill -TERM 2>/dev/null || true
        sleep 2
        echo "$backend_pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    # Ferma frontend
    if [ -n "$frontend_pids" ]; then
        print_status $YELLOW "Fermando processi frontend: $frontend_pids"
        echo "$frontend_pids" | xargs -r kill -TERM 2>/dev/null || true
        sleep 2
        echo "$frontend_pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    # Ferma altri processi Node correlati
    if [ -n "$node_pids" ]; then
        print_status $YELLOW "Fermando processi Node CRM: $node_pids"
        echo "$node_pids" | xargs -r kill -TERM 2>/dev/null || true
        sleep 2
        echo "$node_pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    # Libera porte specifiche
    local port_3000_pid=$(lsof -ti:3000 2>/dev/null || true)
    local port_3001_pid=$(lsof -ti:3001 2>/dev/null || true)
    
    if [ -n "$port_3000_pid" ]; then
        print_status $YELLOW "Liberando porta 3000 (PID: $port_3000_pid)"
        echo "$port_3000_pid" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    if [ -n "$port_3001_pid" ]; then
        print_status $YELLOW "Liberando porta 3001 (PID: $port_3001_pid)"
        echo "$port_3001_pid" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    # Attendi che i processi si fermino
    sleep 3
    
    print_success "Processi CRM fermati"
}

# Funzione per rimozione sicura directory
safe_remove_directory() {
    local dir_path="$1"
    local max_attempts=3
    local attempt=1
    
    if [ ! -d "$dir_path" ]; then
        return 0
    fi
    
    print_status $YELLOW "Rimozione sicura directory: $dir_path"
    
    while [ $attempt -le $max_attempts ]; do
        print_status $BLUE "Tentativo $attempt/$max_attempts di rimozione..."
        
        # Prova rimozione normale
        if rm -rf "$dir_path" 2>/dev/null; then
            print_success "Directory rimossa con successo"
            return 0
        fi
        
        # Se fallisce, prova con sudo
        if sudo rm -rf "$dir_path" 2>/dev/null; then
            print_success "Directory rimossa con sudo"
            return 0
        fi
        
        # Se ancora fallisce, prova a cambiare permessi e rimuovere
        if [ -d "$dir_path" ]; then
            print_warning "Tentativo con cambio permessi..."
            sudo chmod -R 777 "$dir_path" 2>/dev/null || true
            sudo chown -R $USER:$USER "$dir_path" 2>/dev/null || true
            
            if rm -rf "$dir_path" 2>/dev/null; then
                print_success "Directory rimossa dopo cambio permessi"
                return 0
            fi
        fi
        
        ((attempt++))
        if [ $attempt -le $max_attempts ]; then
            print_warning "Tentativo fallito, attendo prima del prossimo..."
            sleep 2
        fi
    done
    
    print_error "Impossibile rimuovere directory dopo $max_attempts tentativi: $dir_path"
    return 1
}

# Funzione per verificare integrità file
verify_file_integrity() {
    local file_path="$1"
    local expected_min_size="$2"
    local file_name=$(basename "$file_path")
    
    if [ ! -f "$file_path" ]; then
        print_error "File $file_name non trovato"
        return 1
    fi
    
    local file_size=$(wc -l < "$file_path")
    if [ "$file_size" -lt "$expected_min_size" ]; then
        print_error "File $file_name troppo piccolo ($file_size righe, minimo $expected_min_size)"
        return 1
    fi
    
    print_success "✓ $file_name verificato ($file_size righe)"
    return 0
}

# Banner
echo -e "${BLUE}"
echo "======================================="
echo "   CRM System - DevOps Sync Script v3.3"
echo "   FASE 1: Validazione Base"
echo "======================================="
echo -e "${NC}"

print_status $BLUE "Inizializzazione sync DevOps config v3.3..."

# STEP 0: Verifica e cambia directory di lavoro
print_status $BLUE "Directory corrente: $(pwd)"
safe_cd_home

# Verifica prerequisiti
if ! command -v git &> /dev/null; then
    print_error "Git non è installato. Installare git prima di continuare."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    print_error "Curl non è installato. Installare curl prima di continuare."
    exit 1
fi

# STEP 1: Ferma tutti i processi CRM
stop_crm_processes

# STEP 2: Backup della configurazione esistente se presente
BACKUP_DIR=""
if [ -d "$DEVOPS_CONFIG_DIR" ]; then
    print_warning "Directory devops-pipeline-fase-1 esistente. Creando backup..."
    BACKUP_DIR="${DEVOPS_CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$DEVOPS_CONFIG_DIR" "$BACKUP_DIR"
    print_status $YELLOW "Backup creato in: $BACKUP_DIR"
fi

# STEP 3: Crea directory devops se non esiste
mkdir -p "$HOME/devops"

# STEP 4: Rimozione sicura directory progetto esistente
if [ -d "$PROJECT_DIR" ]; then
    print_status $YELLOW "Rimozione directory progetto esistente..."
    if ! safe_remove_directory "$PROJECT_DIR"; then
        print_error "Impossibile rimuovere directory progetto"
        
        # Ripristina backup se esiste
        if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
            print_warning "Ripristino backup..."
            rm -rf "$DEVOPS_CONFIG_DIR" 2>/dev/null || true
            mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
            print_success "Backup ripristinato"
        fi
        exit 1
    fi
fi

# STEP 5: Clone fresh del repository
print_status $BLUE "Clone del repository CRM-System..."
if git clone "$REPO_URL" "$PROJECT_DIR"; then
    print_success "Repository clonato con successo"
else
    print_error "Errore durante il clone del repository"
    
    # Ripristina backup se esiste
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        rm -rf "$DEVOPS_CONFIG_DIR" 2>/dev/null || true
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# STEP 6: Verifica che la directory devops-pipeline-fase-1 esista nel repo
if [ ! -d "$PROJECT_DIR/devops-pipeline-fase-1" ]; then
    print_error "Directory devops-pipeline-fase-1 non trovata nel repository"
    
    # Ripristina backup se esiste
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        rm -rf "$DEVOPS_CONFIG_DIR" 2>/dev/null || true
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# STEP 7: Rimuovi directory locale esistente
if [ -d "$DEVOPS_CONFIG_DIR" ]; then
    safe_remove_directory "$DEVOPS_CONFIG_DIR"
fi

# STEP 8: Copiare la directory devops-pipeline-fase-1 nella home
print_status $BLUE "Copia configurazione DevOps..."
if cp -r "$PROJECT_DIR/devops-pipeline-fase-1" "$HOME/"; then
    print_success "Configurazione DevOps copiata con successo"
else
    print_error "Errore durante la copia della configurazione"
    
    # Ripristina backup se esiste
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# STEP 9: Verifica che la copia sia avvenuta correttamente
if [ ! -d "$DEVOPS_CONFIG_DIR" ] || [ -z "$(ls -A "$DEVOPS_CONFIG_DIR" 2>/dev/null)" ]; then
    print_error "Directory devops-pipeline-fase-1 vuota o non creata"
    
    # Ripristina backup se esiste
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        rm -rf "$DEVOPS_CONFIG_DIR" 2>/dev/null || true
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# STEP 10: Rendere eseguibili tutti gli script
print_status $BLUE "Rendendo eseguibili gli script..."
chmod +x "$HOME/devops-pipeline-fase-1"/*.sh

# STEP 11: Verifica integrità dei file con dimensioni minime attese
print_status $BLUE "Verifica integrità files..."

declare -A expected_sizes=(
    ["prerequisites.sh"]=50
    ["deploy.sh"]=200
    ["test.sh"]=250
    ["sync-devops-config.sh"]=50
)

all_files_ok=true

for file in "${!expected_sizes[@]}"; do
    if ! verify_file_integrity "$HOME/devops-pipeline-fase-1/$file" "${expected_sizes[$file]}"; then
        all_files_ok=false
    fi
done

# STEP 12: Se i file non sono OK, ripristina backup
if [ "$all_files_ok" = false ]; then
    print_error "Verifica integrità fallita!"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        safe_remove_directory "$DEVOPS_CONFIG_DIR"
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
fi

# STEP 13: Verifica contenuto specifico test.sh (non deve avere set -e)
if grep -q "^set -e" "$HOME/devops-pipeline-fase-1/test.sh"; then
    print_error "test.sh contiene ancora 'set -e' - sync non aggiornato"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_warning "Ripristino backup..."
        safe_remove_directory "$DEVOPS_CONFIG_DIR"
        mv "$BACKUP_DIR" "$DEVOPS_CONFIG_DIR"
        print_success "Backup ripristinato"
    fi
    exit 1
else
    print_success "✓ test.sh verificato - nessun 'set -e' trovato"
fi

# STEP 14: Verifica versione test.sh (deve essere v2.0+)
if grep -q "v2.0\|v3.0" "$HOME/devops-pipeline-fase-1/test.sh"; then
    version=$(grep -o "v[0-9]\+\.[0-9]\+" "$HOME/devops-pipeline-fase-1/test.sh" | head -1)
    print_success "✓ test.sh versione $version verificata"
else
    print_warning "test.sh potrebbe non essere la versione più recente"
fi

# STEP 15: Rimuovi backup se tutto OK
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    print_success "Backup rimosso - sync completato con successo"
fi

# STEP 16: Ricrea/aggiorna symlink per facilità d'uso
rm -f "$HOME/devops-scripts" 2>/dev/null || true
ln -s "$HOME/devops-pipeline-fase-1" "$HOME/devops-scripts"
print_status $GREEN "Symlink aggiornato: ~/devops-scripts -> ~/devops-pipeline-fase-1"

# STEP 17: CAMBIO DIRECTORY ESPLICITO ALLA DIRECTORY SINCRONIZZATA
print_status $BLUE "Cambio directory alla configurazione sincronizzata..."
cd "$DEVOPS_CONFIG_DIR"
print_success "Directory corrente: $(pwd)"

# STEP 18: Output informazioni dettagliate
echo -e "${GREEN}"
echo "======================================="
echo "   SINCRONIZZAZIONE COMPLETATA v3.3"
echo "======================================="
echo -e "${NC}"
echo "Directory progetto: $PROJECT_DIR"
echo "Directory DevOps: $HOME/devops-pipeline-fase-1"
echo "Directory corrente: $(pwd)"
echo "Symlink: $HOME/devops-scripts"
echo "Log file: $LOG_FILE"
echo ""

# Mostra dettagli file sincronizzati NELLA DIRECTORY CORRENTE
echo "File sincronizzati (directory corrente):"
for file in prerequisites.sh deploy.sh test.sh sync-devops-config.sh; do
    if [ -f "$file" ]; then
        size=$(wc -l < "$file")
        echo "  ✓ $file ($size righe)"
    fi
done

echo ""
echo "Prossimi passi (sei già nella directory corretta):"
echo "1. ./prerequisites.sh"
echo "2. ./deploy.sh"
echo "3. ./test.sh"
echo ""

print_success "Sync v3.3 completato con successo!"
print_status $GREEN "Sei ora posizionato nella directory DevOps sincronizzata"
print_status $GREEN "Sistema pronto per operazioni DevOps"

exit 0