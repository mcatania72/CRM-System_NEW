#!/bin/bash

# Deploy Containers Script - FASE 2
# Gestione completa Docker Compose per CRM System

set -e

# Configurazioni
CRM_SYSTEM_DIR="$HOME/devops/CRM-System"
COMPOSE_FILE="devops-pipeline-fase-2/docker-compose.yml"
LOG_FILE="$HOME/deploy-containers.log"
PROJECT_NAME="crm-system"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Funzione per verificare prerequisites
check_prerequisites() {
    log_info "Verifica prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker non trovato. Esegui: ./prerequisites-docker.sh"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose non trovato. Esegui: ./prerequisites-docker.sh"
        exit 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker non accessibile. Verifica permessi o esegui: sudo usermod -aG docker $USER"
        exit 1
    fi
    
    # Verifica directory CRM-System
    if [ ! -d "$CRM_SYSTEM_DIR" ]; then
        log_error "Directory $CRM_SYSTEM_DIR non trovata. Esegui sync prima."
        exit 1
    fi
    
    # Verifica backend e frontend
    if [ ! -d "$CRM_SYSTEM_DIR/backend" ] || [ ! -d "$CRM_SYSTEM_DIR/frontend" ]; then
        log_error "Directory backend o frontend non trovate in $CRM_SYSTEM_DIR"
        exit 1
    fi
    
    log_success "Prerequisites OK"
}

# Funzione per verificare file compose
check_compose_files() {
    cd "$CRM_SYSTEM_DIR"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "File $COMPOSE_FILE non trovato in $CRM_SYSTEM_DIR"
        exit 1
    fi
    
    # Verifica sintassi compose
    if ! docker-compose -f "$COMPOSE_FILE" config >/dev/null 2>&1; then
        log_error "Errore sintassi in $COMPOSE_FILE"
        exit 1
    fi
    
    log_success "File Compose validi"
}

# Funzione per eseguire docker-compose dal directory corretto
run_compose() {
    cd "$CRM_SYSTEM_DIR"
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" "$@"
}

# Funzione per mostrare status containers
show_status() {
    echo ""
    echo "======================================="
    echo "   CRM System - Container Status"
    echo "   FASE 2: Containerizzazione"
    echo "======================================="
    
    cd "$CRM_SYSTEM_DIR"
    
    # Status containers
    log_info "Status Container:"
    if run_compose ps | grep -q "Up"; then
        echo ""
        run_compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        # Health checks
        log_info "Health Checks:"
        for service in backend frontend; do
            if run_compose ps "$service" | grep -q "Up"; then
                local health=$(docker inspect --format='{{.State.Health.Status}}' "crm-${service}" 2>/dev/null || echo "unknown")
                case $health in
                    "healthy")
                        echo -e "  ${GREEN}✓${NC} $service: HEALTHY"
                        ;;
                    "unhealthy")
                        echo -e "  ${RED}✗${NC} $service: UNHEALTHY"
                        ;;
                    "starting")
                        echo -e "  ${YELLOW}⏳${NC} $service: STARTING"
                        ;;
                    *)
                        echo -e "  ${CYAN}?${NC} $service: NO HEALTH CHECK"
                        ;;
                esac
            else
                echo -e "  ${RED}✗${NC} $service: NOT RUNNING"
            fi
        done
        
        # Test connettività
        echo ""
        log_info "Test Connettività:"
        
        # Test backend
        if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Backend API: http://localhost:3001/api/health"
        else
            echo -e "  ${RED}✗${NC} Backend API: NON RAGGIUNGIBILE"
        fi
        
        # Test frontend
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Frontend: http://localhost:3000"
        else
            echo -e "  ${RED}✗${NC} Frontend: NON RAGGIUNGIBILE"
        fi
        
    else
        log_warning "Nessun container in esecuzione"
    fi
    
    # Informazioni utili
    echo ""
    log_info "Informazioni Accesso:"
    echo "  • Frontend: http://localhost:3000"
    echo "  • Backend API: http://localhost:3001/api"
    echo "  • Health Check: http://localhost:3001/api/health"
    echo "  • Credenziali: admin@crm.local / admin123"
    
    echo ""
    log_info "Comandi Utili:"
    echo "  • ./deploy-containers.sh logs       # Visualizza logs"
    echo "  • ./deploy-containers.sh restart    # Riavvia container"
    echo "  • ./test-containers.sh             # Test completi"
    echo ""
}

# Funzione per avviare containers
start_containers() {
    echo ""
    echo "======================================="
    echo "   CRM System - Container Start"
    echo "   FASE 2: Containerizzazione"
    echo "======================================="
    
    check_prerequisites
    check_compose_files
    
    log_info "Avvio container CRM System..."
    
    cd "$CRM_SYSTEM_DIR"
    
    # Crea network se non esiste
    if ! docker network ls | grep -q "crm-network"; then
        log_info "Creazione network crm-network..."
        docker network create crm-network
    fi
    
    # Build e start containers
    log_info "Build e avvio container..."
    
    if run_compose up -d --build; then
        log_success "Container avviati con successo"
        
        # Attendi che i servizi siano pronti
        log_info "Attendo che i servizi siano pronti..."
        
        local retries=0
        local max_retries=30
        
        while [ $retries -lt $max_retries ]; do
            if curl -s http://localhost:3001/api/health >/dev/null 2>&1 && \
               curl -s http://localhost:3000 >/dev/null 2>&1; then
                log_success "Tutti i servizi sono pronti!"
                break
            fi
            
            echo -n "."
            sleep 2
            ((retries++))
        done
        
        if [ $retries -eq $max_retries ]; then
            log_warning "Timeout nell'attesa dei servizi. Verifica manualmente."
        fi
        
        echo ""
        log_success "Deploy container completato!"
        
    else
        log_error "Errore nell'avvio container"
        exit 1
    fi
}

# Funzione per fermare containers
stop_containers() {
    echo ""
    echo "======================================="
    echo "   CRM System - Container Stop"
    echo "======================================="
    
    log_info "Arresto container..."
    
    if run_compose down; then
        log_success "Container arrestati con successo"
    else
        log_warning "Alcuni container potrebbero non essere stati arrestati correttamente"
    fi
}

# Funzione per cleanup completo
cleanup_containers() {
    echo ""
    echo "======================================="
    echo "   CRM System - Container Cleanup"
    echo "======================================="
    
    log_warning "ATTENZIONE: Questo rimuoverà tutti i container, volumi e immagini!"
    read -p "Sei sicuro? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup completo..."
        
        cd "$CRM_SYSTEM_DIR"
        
        # Stop e rimozione container
        run_compose down -v --remove-orphans
        
        # Rimozione immagini
        run_compose down --rmi all
        
        # Pulizia volumi orfani
        docker volume prune -f
        
        # Pulizia network
        docker network rm crm-network 2>/dev/null || true
        
        log_success "Cleanup completato"
    else
        log_info "Cleanup annullato"
    fi
}

# Funzione per mostrare logs
show_logs() {
    local service=${1:-""}
    
    echo "======================================="
    echo "   CRM System - Container Logs"
    echo "======================================="
    
    cd "$CRM_SYSTEM_DIR"
    
    if [ -n "$service" ]; then
        log_info "Logs per servizio: $service"
        run_compose logs -f "$service"
    else
        log_info "Logs per tutti i servizi (Ctrl+C per uscire)"
        run_compose logs -f
    fi
}

# Funzione per build forzato
force_build() {
    echo ""
    echo "======================================="
    echo "   CRM System - Force Build"
    echo "======================================="
    
    check_prerequisites
    check_compose_files
    
    log_info "Build forzato container (no cache)..."
    
    if run_compose build --no-cache; then
        log_success "Build completato con successo"
    else
        log_error "Errore durante il build"
        exit 1
    fi
}

# Main script logic
case "${1:-start}" in
    "start")
        start_containers
        show_status
        ;;
    "stop")
        stop_containers
        ;;
    "restart")
        stop_containers
        sleep 2
        start_containers
        show_status
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "build")
        force_build
        ;;
    "down")
        stop_containers
        ;;
    "cleanup")
        cleanup_containers
        ;;
    "ps")
        cd "$CRM_SYSTEM_DIR"
        run_compose ps
        ;;
    "exec")
        if [ -z "$2" ]; then
            echo "Uso: $0 exec <service> [comando]"
            echo "Servizi disponibili: backend, frontend"
            exit 1
        fi
        cd "$CRM_SYSTEM_DIR"
        run_compose exec "$2" "${3:-sh}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|build|down|cleanup|ps|exec}"
        echo ""
        echo "Comandi disponibili:"
        echo "  start     - Avvia tutti i container (default)"
        echo "  stop      - Ferma tutti i container"
        echo "  restart   - Riavvia tutti i container"
        echo "  status    - Mostra status dettagliato container"
        echo "  logs      - Mostra logs container (logs <service> per servizio specifico)"
        echo "  build     - Build forzato senza cache"
        echo "  down      - Ferma e rimuove container"
        echo "  cleanup   - Cleanup completo (container + volumi + immagini)"
        echo "  ps        - Lista container attivi"
        echo "  exec      - Esegui comando in container (exec <service> [comando])"
        echo ""
        echo "Esempi:"
        echo "  $0                          # Avvia container"
        echo "  $0 logs backend             # Logs solo backend"
        echo "  $0 exec backend bash        # Shell nel container backend"
        echo ""
        exit 1
        ;;
esac