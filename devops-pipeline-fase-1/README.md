# DevOps Pipeline - FASE 1: Validazione Base

Questa directory contiene gli script per la **FASE 1: Validazione Base** del progetto CRM System.

## 🎯 Obiettivo della Fase 1

Assicurarsi che l'applicazione compili e funzioni correttamente prima di introdurre elementi di complessità maggiore come containerizzazione avanzata e CI/CD.

## 📁 Script Inclusi

### 1. `sync-devops-config.sh`
**Scopo**: Sincronizza la configurazione DevOps dal repository GitHub

- Cancella il contenuto eventuale di `devops-pipeline-fase-1` su DEV_VM
- Scarica l'ultima versione del repository da GitHub
- Copia la configurazione DevOps nella home dell'utente
- Imposta i permessi corretti per tutti gli script
- Crea un symlink `~/devops-scripts` per facilità d'uso

**Uso**:
```bash
./sync-devops-config.sh
```

### 2. `prerequisites.sh`
**Scopo**: Verifica e installa tutti i prerequisiti necessari

**Verifica**:
- Node.js >= 18.0.0
- npm >= 8.0.0
- Git
- Python3 e build tools
- Struttura directory progetto
- Connettività di rete

**Installazione automatica**:
- Node.js tramite NodeSource (se mancante)
- Build tools essenziali
- Strumenti globali TypeScript

**Uso**:
```bash
./prerequisites.sh
```

### 3. `deploy.sh`
**Scopo**: Compila e avvia l'applicazione CRM (backend + frontend)

**Funzionalità**:
- Cleanup automatico processi precedenti
- Installazione dipendenze con retry logic
- Build di backend e frontend
- Avvio servizi con health checks
- Monitoraggio stato applicazione
- Gestione PID e logging

**Comandi disponibili**:
```bash
./deploy.sh start    # Avvia l'applicazione (default)
./deploy.sh stop     # Ferma l'applicazione
./deploy.sh restart  # Riavvia l'applicazione
./deploy.sh status   # Mostra stato corrente
```

**Porte utilizzate**:
- Backend: `http://localhost:3001`
- Frontend: `http://localhost:3000`
- API Docs: `http://localhost:3001/api/docs`
- Health Check: `http://localhost:3001/api/health`

### 4. `test.sh`
**Scopo**: Esegue test automatizzati completi per la validazione

**Test Automatici**:
- ✅ Connettività di base
- ✅ Prerequisiti di sistema
- ✅ Compilazione backend/frontend
- ✅ Servizi attivi e health checks
- ✅ Autenticazione e API
- ✅ Database e persistenza
- ✅ Performance di base

**Comandi disponibili**:
```bash
./test.sh           # Esegue tutti i test automatici
./test.sh manual    # Mostra checklist test manuali
./test.sh report    # Mostra ultimo report JSON
```

**Output**:
- Report dettagliato con successo/fallimento di ogni test
- File JSON con risultati: `~/test-results-fase1.json`
- Log completo: `~/test-fase1.log`
- Checklist test manuali

## 🚀 Flusso di Utilizzo

### Primo Setup
1. Crea la directory sulla DEV_VM:
   ```bash
   mkdir -p ~/devops-pipeline-fase-1
   cd ~/devops-pipeline-fase-1
   ```

2. Sincronizza la configurazione:
   ```bash
   ./sync-devops-config.sh
   ```

3. Verifica prerequisiti:
   ```bash
   ./prerequisites.sh
   ```

4. Avvia l'applicazione:
   ```bash
   ./deploy.sh
   ```

5. Esegui i test:
   ```bash
   ./test.sh
   ```

### Uso Quotidiano
```bash
# Aggiorna configurazione
./sync-devops-config.sh

# Avvia applicazione
./deploy.sh start

# Controlla stato
./deploy.sh status

# Esegui test completi
./test.sh

# Ferma applicazione
./deploy.sh stop
```

## 📊 Metriche di Successo

**Criteri per completare la Fase 1**:
- ✅ 100% build success rate
- ✅ Backend e Frontend compilano senza errori
- ✅ Database SQLite si inizializza
- ✅ API endpoints rispondono
- ✅ Login funziona con credenziali di test
- ✅ CRUD operations funzionano
- ✅ Dashboard carica dati
- ✅ Tutti i test automatici passano
- ✅ Test manuali completati con successo

## 🔍 Troubleshooting

### Problemi Comuni

**Errore: "Port already in use"**
```bash
# Verifica processi attivi
./deploy.sh status

# Ferma tutto e riavvia
./deploy.sh stop
./deploy.sh start
```

**Errore: "Node.js not found"**
```bash
# Reinstalla prerequisiti
./prerequisites.sh
```

**Errore: "Build failed"**
```bash
# Controlla i log
tail -f ~/backend.log ~/frontend.log

# Pulisci e rebuilda
cd ~/devops/CRM-System
npm run clean  # se disponibile
./deploy.sh restart
```

**Test falliti**
```bash
# Mostra report dettagliato
./test.sh report

# Controlla log specifici
cat ~/test-fase1.log

# Test manuali
./test.sh manual
```

### File di Log
- `~/sync-devops.log` - Log sincronizzazione
- `~/prerequisites.log` - Log verifica prerequisiti
- `~/deploy.log` - Log deploy e startup
- `~/backend.log` - Log backend applicazione
- `~/frontend.log` - Log frontend applicazione
- `~/test-fase1.log` - Log test automatici
- `~/test-results-fase1.json` - Risultati test in JSON
- `~/crm-pids.txt` - PID processi attivi

### Directory Importanti
- `~/devops/CRM-System/` - Codice sorgente clonato
- `~/devops-pipeline-fase-1/` - Script DevOps
- `~/devops-scripts` - Symlink agli script

## 🔑 Credenziali di Test

**Login Amministratore**:
- Email: `admin@crm.local`
- Password: `admin123`
- Ruolo: Administrator

## 🌐 URL Applicazione

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001/api
- **Health Check**: http://localhost:3001/api/health
- **API Documentation**: http://localhost:3001/api/docs

## ✅ Checklist Validazione Completa

Prima di passare alla **FASE 2**, assicurarsi che:

- [ ] Tutti gli script eseguono senza errori
- [ ] `./prerequisites.sh` completa con successo
- [ ] `./deploy.sh` avvia backend e frontend
- [ ] `./test.sh` tutti i test automatici passano
- [ ] Login web funziona correttamente
- [ ] Dashboard si carica senza errori
- [ ] API rispondono alle chiamate
- [ ] È possibile creare/modificare dati
- [ ] Nessun errore nei log applicazione
- [ ] Performance accettabili (< 3s caricamento pagine)

## 🎯 Prossimo Step: FASE 2

Una volta completata con successo la **FASE 1**, si può procedere alla **FASE 2: Containerizzazione Completa** che includerà:
- Ottimizzazione Docker esistente
- Multi-stage builds
- Health checks avanzati
- Network security
- Volume persistence

---

**Per supporto**: Controllare i file di log sopra elencati e verificare che tutti i prerequisiti siano soddisfatti.