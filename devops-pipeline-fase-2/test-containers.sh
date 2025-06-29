#!/bin/bash
# VERSIONE DI DEBUG SEMPLIFICATA - v2

echo "--- ESEGUO VERSIONE DI DEBUG v2 DI test-containers.sh ---"
echo "Se vedi questo messaggio, il file è stato aggiornato."

set -e

COMPOSE_FILE="devops-pipeline-fase-2/docker-compose.yml"

echo "[INFO] Verifica container..."
docker-compose -f "$COMPOSE_FILE" ps

# Semplice controllo che il backend sia "running"
BACKEND_STATE=$(docker-compose -f "$COMPOSE_FILE" ps -q backend | xargs docker inspect -f '{{.State.Status}}' 2>/dev/null || echo "error")
if [ "$BACKEND_STATE" == "running" ]; then
    echo "[SUCCESS] Il container del backend è in esecuzione."
else
    echo "[ERROR] Il container del backend non è in esecuzione."
    exit 1
fi

echo "[SUCCESS] Test minimale completato con successo."
exit 0
