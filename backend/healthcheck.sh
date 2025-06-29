#!/bin/sh
# Healthcheck script per il backend

set -e

# Usa wget per fare una richiesta all'endpoint di health.
# -q: quiet mode
# -O -: output to stdout
# --spider: non scarica il contenuto, controlla solo l'esistenza e gli header
# Il comando fallirà se il server non risponde con 2xx o 3xx.
wget -q --spider http://localhost:4001/api/health || exit 1
