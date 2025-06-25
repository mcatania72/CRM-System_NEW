#!/bin/bash

# create-admin.sh
# Script per creare utente admin direttamente nel database SQLite

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================="
echo "   CRM System - Creazione Utente Admin"
echo "=======================================${NC}"

# Directory backend
BACKEND_DIR="$HOME/devops/CRM-System/backend"
DB_FILE="$BACKEND_DIR/database.sqlite"

if [[ ! -d "$BACKEND_DIR" ]]; then
    echo -e "${RED}❌ Directory backend non trovata: $BACKEND_DIR${NC}"
    echo "Eseguire prima: ./sync-devops-config.sh"
    exit 1
fi

cd "$BACKEND_DIR"

# Verifica se bcryptjs è installato
if [[ ! -d "node_modules" ]]; then
    echo -e "${YELLOW}📦 Installazione dipendenze...${NC}"
    npm install
fi

echo -e "${BLUE}🔐 Creazione hash password...${NC}"

# Crea hash della password usando Node.js
HASHED_PASSWORD=$(node -e "
const bcrypt = require('bcryptjs');
console.log(bcrypt.hashSync('admin123', 10));
")

echo -e "${BLUE}💾 Inizializzazione database...${NC}"

# Crea/aggiorna il database SQLite
sqlite3 "$DB_FILE" << EOF
-- Crea tabella user se non esiste
CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR UNIQUE NOT NULL,
    password VARCHAR NOT NULL,
    firstName VARCHAR NOT NULL,
    lastName VARCHAR NOT NULL,
    role VARCHAR NOT NULL DEFAULT 'salesperson',
    isActive BOOLEAN NOT NULL DEFAULT 1,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Elimina utente admin esistente (se presente)
DELETE FROM user WHERE email = 'admin@crm.local';

-- Inserisci nuovo utente admin
INSERT INTO user (email, password, firstName, lastName, role, isActive, createdAt, updatedAt)
VALUES (
    'admin@crm.local',
    '$HASHED_PASSWORD',
    'Admin',
    'CRM',
    'admin',
    1,
    datetime('now'),
    datetime('now')
);

-- Verifica inserimento
SELECT 'Utente creato:' as status, email, firstName, lastName, role, isActive 
FROM user WHERE email = 'admin@crm.local';
EOF

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}🎉 Utente admin creato con successo!${NC}"
    echo ""
    echo -e "${GREEN}📧 Email: admin@crm.local${NC}"
    echo -e "${GREEN}🔑 Password: admin123${NC}"
    echo -e "${GREEN}👤 Ruolo: admin${NC}"
    echo ""
    echo "Ora puoi accedere all'applicazione con queste credenziali."
    echo ""
    echo "Per testare il login:"
    echo "  curl -X POST http://localhost:3001/api/auth/login \\"
    echo "       -H \"Content-Type: application/json\" \\"
    echo "       -d '{\"email\":\"admin@crm.local\",\"password\":\"admin123\"}'"
    echo ""
else
    echo -e "${RED}❌ Errore nella creazione utente admin${NC}"
    exit 1
fi