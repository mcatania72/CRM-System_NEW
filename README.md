# CRM System

## 🚀 Sistema CRM completo con React, TypeScript, Material-UI, Express, TypeORM e SQLite

### 📋 Panoramica del progetto:
Sistema di gestione clienti (Customer Relationship Management) professionale con architettura full-stack moderna.

### 🏗️ Architettura:
- **Backend**: Node.js + Express + TypeScript + TypeORM + SQLite
- **Frontend**: React + TypeScript + Material-UI + Vite
- **Database**: SQLite per persistenza dei dati
- **Autenticazione**: JWT tokens per sicurezza
- **Containerizzazione**: Docker e Docker Compose

### ✨ Funzionalità implementate:
1. **📊 Dashboard** con statistiche e grafici in tempo reale
2. **👥 Gestione Clienti** completa (CRUD)
3. **💼 Gestione Opportunità** di vendita con pipeline
4. **📅 Gestione Attività** quotidiane e follow-up
5. **💬 Gestione Interazioni** con tracciamento completo
6. **🔐 Sistema di autenticazione** con ruoli utente
7. **📈 Reportistica** avanzata e analytics
8. **🎯 Filtraggio** e ricerca avanzata
9. **📱 Interfaccia responsive** per tutti i dispositivi

### 🚀 Avvio rapido:

#### 🔧 Metodo 1: Docker (Raccomandato)
```bash
git clone https://github.com/mcatania72/CRM-System.git
cd CRM-System
docker-compose up --build
```

#### 💻 Metodo 2: Sviluppo locale

**Backend:**
```bash
cd backend
npm install
npm run dev
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

#### 🎮 Metodo 3: Server semplice
```bash
npm install
npm start
```

### 🔐 Account di prova:
- **Email**: admin@crm.local
- **Password**: admin123
- **Ruolo**: Administrator

### 🌐 URLs di accesso:
- **Frontend React**: http://localhost:3000
- **Backend API**: http://localhost:3001/api
- **Health Check**: http://localhost:3001/api/health
- **Documentazione API**: http://localhost:3001/api/docs

### 🛠️ Tecnologie utilizzate:

**Backend:**
- Node.js 18+
- Express.js
- TypeScript
- TypeORM
- SQLite3
- JWT Authentication
- bcryptjs per password hashing
- express-validator per validazione
- helmet per sicurezza
- express-rate-limit per rate limiting

**Frontend:**
- React 18
- TypeScript
- Material-UI (MUI) v5
- React Router v6
- Axios per API calls
- React Hook Form per form management
- Recharts per grafici
- date-fns per gestione date

**DevOps & Tools:**
- Vite per build system
- Docker & Docker Compose
- ESLint & Prettier
- Hot-reload per sviluppo

### 📂 Struttura progetto:
```
CRM-System/
├── backend/              # Backend TypeScript + Express
│   ├── src/
│   │   ├── controllers/  # Route controllers
│   │   ├── entities/     # TypeORM entities
│   │   ├── middleware/   # Custom middleware
│   │   ├── routes/       # API routes
│   │   └── app.ts        # Main application
│   ├── Dockerfile
│   └── package.json
├── frontend/             # Frontend React + TypeScript
│   ├── src/
│   │   ├── components/   # React components
│   │   ├── pages/        # Page components
│   │   ├── contexts/     # React contexts
│   │   ├── services/     # API services
│   │   └── main.tsx      # Entry point
│   ├── Dockerfile
│   └── package.json
├── docker-compose.yml    # Container orchestration
├── server.js            # Simple Express server
└── README.md
```

### 🐳 Docker Commands:
```bash
# Avvia tutto
docker-compose up --build

# Avvia in background
docker-compose up -d

# Vedi logs
docker-compose logs -f

# Ferma tutto
docker-compose down

# Reset completo
docker-compose down -v && docker-compose up --build
```

### 🔧 API Endpoints principali:

**Autenticazione:**
- `POST /api/auth/login` - Login utente
- `GET /api/auth/profile` - Profilo utente

**Clienti:**
- `GET /api/customers` - Lista clienti
- `POST /api/customers` - Crea cliente
- `GET /api/customers/:id` - Dettagli cliente
- `PUT /api/customers/:id` - Aggiorna cliente
- `DELETE /api/customers/:id` - Elimina cliente

**Opportunità:**
- `GET /api/opportunities` - Lista opportunità
- `POST /api/opportunities` - Crea opportunità
- `PUT /api/opportunities/:id` - Aggiorna opportunità

**Dashboard:**
- `GET /api/dashboard/stats` - Statistiche generali
- `GET /api/dashboard/analytics` - Analytics avanzate

### 📊 Features avanzate:

- **🔍 Ricerca intelligente** - Ricerca full-text su tutti i campi
- **📊 Analytics** - Grafici interattivi e metriche KPI
- **🎯 Pipeline di vendita** - Gestione fasi opportunità
- **📅 Calendar integration** - Gestione appuntamenti
- **📱 Mobile responsive** - Perfetto su tutti i dispositivi
- **🔔 Notifiche** - Sistema di notifiche in tempo reale
- **📈 Reporting** - Report personalizzabili
- **🔒 Role-based access** - Controllo accessi granulare

### 🚀 Produzione:

Il sistema è pronto per la produzione con:
- ✅ Database SQLite ottimizzato
- ✅ Autenticazione sicura con JWT
- ✅ Rate limiting e security headers
- ✅ Error handling completo
- ✅ Logging strutturato
- ✅ Health checks
- ✅ Docker containerization

### 📞 Supporto:

Per domande o problemi:
1. Controlla la documentazione
2. Verifica i logs con `docker-compose logs`
3. Testa le API con il health check endpoint

---

**🎉 Il tuo CRM System è pronto all'uso!**