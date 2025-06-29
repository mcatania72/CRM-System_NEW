#!/bin/bash

# create-admin-node.sh
# Script per creare utente admin usando Node.js senza SQLite3 command line

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================="
echo "   CRM System - Creazione Utente Admin"
echo "   (Versione Node.js)"
echo "=======================================${NC}"

# Directory backend
BACKEND_DIR="$HOME/devops/CRM-System/backend"

if [[ ! -d "$BACKEND_DIR" ]]; then
    echo -e "${RED}❌ Directory backend non trovata: $BACKEND_DIR${NC}"
    echo "Eseguire prima: ./sync-devops-config.sh"
    exit 1
fi

cd "$BACKEND_DIR"

# Verifica se le dipendenze sono installate
if [[ ! -d "node_modules" ]]; then
    echo -e "${YELLOW}📦 Installazione dipendenze...${NC}"
    npm install
fi

echo -e "${BLUE}🔐 Creazione utente admin con Node.js...${NC}"

# Crea script temporaneo Node.js per inizializzare il database
cat > temp-create-admin.js << 'EOF'
const Database = require('sqlite3').Database;
const bcrypt = require('bcryptjs');
const path = require('path');

const dbPath = path.join(__dirname, 'database.sqlite');
console.log('📁 Database path:', dbPath);

const db = new Database(dbPath, (err) => {
    if (err) {
        console.error('❌ Errore connessione database:', err.message);
        process.exit(1);
    }
    console.log('✅ Connesso al database SQLite');
});

// Crea hash della password
const password = 'admin123';
const hashedPassword = bcrypt.hashSync(password, 10);

// Crea tabella user se non esiste
db.serialize(() => {
    // Crea tabella
    db.run(`CREATE TABLE IF NOT EXISTS user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email VARCHAR UNIQUE NOT NULL,
        password VARCHAR NOT NULL,
        firstName VARCHAR NOT NULL,
        lastName VARCHAR NOT NULL,
        role VARCHAR NOT NULL DEFAULT 'salesperson',
        isActive BOOLEAN NOT NULL DEFAULT 1,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
        if (err) {
            console.error('❌ Errore creazione tabella:', err.message);
            process.exit(1);
        }
        console.log('📊 Tabella user verificata/creata');
    });

    // Elimina admin esistente
    db.run(`DELETE FROM user WHERE email = ?`, ['admin@crm.local'], (err) => {
        if (err) {
            console.warn('⚠️  Warning delete:', err.message);
        }
    });

    // Inserisci nuovo admin
    db.run(`INSERT INTO user (email, password, firstName, lastName, role, isActive, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
        ['admin@crm.local', hashedPassword, 'Admin', 'CRM', 'admin', 1],
        function(err) {
            if (err) {
                console.error('❌ Errore inserimento admin:', err.message);
                process.exit(1);
            }
            
            console.log('🎉 Utente admin creato con successo!');
            console.log('📧 Email: admin@crm.local');
            console.log('🔑 Password: admin123');
            console.log('👤 Ruolo: admin');
            console.log('🆔 Row ID:', this.lastID);
            
            // Verifica inserimento
            db.get(`SELECT email, firstName, lastName, role, isActive, createdAt 
                    FROM user WHERE email = ?`, ['admin@crm.local'], (err, row) => {
                if (err) {
                    console.error('❌ Errore verifica:', err.message);
                } else if (row) {
                    console.log('✅ Verifica utente:', row);
                } else {
                    console.error('❌ Utente non trovato dopo inserimento');
                }
                
                db.close((err) => {
                    if (err) {
                        console.error('❌ Errore chiusura db:', err.message);
                        process.exit(1);
                    }
                    console.log('🔌 Database chiuso');
                    console.log('');
                    console.log('🚀 Ora puoi accedere all\'applicazione!');
                    console.log('   Frontend: http://localhost:3000');
                    console.log('   Email: admin@crm.local');
                    console.log('   Password: admin123');
                });
            });
        });
});
EOF

# Esegui lo script Node.js
if node temp-create-admin.js; then
    echo ""
    echo -e "${GREEN}✅ Script completato con successo!${NC}"
    
    # Cleanup
    rm -f temp-create-admin.js
    
    echo ""
    echo "Per testare il login:"
    echo "  curl -X POST http://localhost:3001/api/auth/login \\"
    echo "       -H \"Content-Type: application/json\" \\"
    echo "       -d '{\"email\":\"admin@crm.local\",\"password\":\"admin123\"}'"
else
    echo -e "${RED}❌ Errore nell'esecuzione dello script${NC}"
    rm -f temp-create-admin.js
    exit 1
fi