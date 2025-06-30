#!/bin/bash

# Emergency Docker Compose Fix - Risolve comando backend rotto

set -euo pipefail

LOG_FILE="$HOME/emergency-fix.log"
CRM_DIR="$HOME/crm-docker"

log() {
    echo "[$(date +'%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚨 Emergency fix for broken backend command"

# Stop tutto
cd "$CRM_DIR"
docker-compose down

# Fix comando backend direttamente nel file
log "📝 Fixing backend command in docker-compose.yml"

# Backup
cp docker-compose.yml docker-compose.yml.backup

# Sostituisci comando multilinea con array format
sed -i '/command: >/,/^[[:space:]]*"$/c\
    command: ["sh", "-c", "if [ ! -d node_modules ]; then echo '\''Installing dependencies...'\''; npm install --production --no-audit --no-fund; fi; echo '\''Starting backend...'\''; npm start"]' docker-compose.yml

log "✅ Command fixed in docker-compose.yml"

# Verifica fix
log "🔍 Verifying fix..."
grep -A 1 'command: \[' docker-compose.yml || log "❌ Fix failed"

# Restart
log "🔄 Restarting services..."
docker-compose up -d

log "🎉 Emergency fix completed"

# Monitor backend
sleep 5
docker-compose logs backend | tail -10
