import "reflect-metadata";
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { AppDataSource } from './data-source';

// Import routes
import authRoutes from './routes/auth';
import customerRoutes from './routes/customers';
import opportunityRoutes from './routes/opportunities';
import activityRoutes from './routes/activities';
import interactionRoutes from './routes/interactions';
import dashboardRoutes from './routes/dashboard';

const app = express();
const PORT = parseInt(process.env.PORT || '4001', 10); // Fix: assicura che sia number

// Rate limiting - Testing-friendly configuration
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minuti
    max: 10000, // 10k richieste per testing (era 100)
    skip: (req) => {
        // Skip rate limiting per localhost durante testing
        const isLocalhost = req.ip === '127.0.0.1' || 
                           req.ip === '::1' || 
                           req.ip === '::ffff:127.0.0.1' ||
                           req.connection.remoteAddress === '127.0.0.1' ||
                           req.connection.remoteAddress === '::1';
        return isLocalhost;
    },
    message: {
        error: 'Too many requests from this IP',
        retryAfter: '15 minutes'
    },
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// Middleware di sicurezza
app.use(helmet());
app.use(limiter);

// CORS - Supporta sia dev che preview mode
app.use(cors({
    origin: [
        process.env.FRONTEND_URL || 'http://localhost:3000',
        'http://localhost:4173', // Vite preview
        'http://localhost:3000',   // Vite dev
        'http://192.168.1.29:4173', // VM access preview
        'http://192.168.1.29:3000'  // VM access dev
    ],
    credentials: true
}));

// Parser per JSON
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/opportunities', opportunityRoutes);
app.use('/api/activities', activityRoutes);
app.use('/api/interactions', interactionRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Health check
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ message: 'Endpoint non trovato' });
});

// Error handler globale
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Errore:', err);
    
    if (err.type === 'entity.parse.failed') {
        return res.status(400).json({ message: 'JSON non valido' });
    }
    
    res.status(500).json({ 
        message: 'Errore interno del server',
        error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// Inizializzazione database e avvio server
AppDataSource.initialize()
    .then(async () => {
        console.log("Database connesso con successo");
        
        // Crea utente admin di default se non esiste
        await createDefaultAdmin();
        
        // Fix: usa solo PORT (number) e host string separato
        app.listen(PORT, '0.0.0.0', () => {
            console.log(`Server in esecuzione sulla porta ${PORT}`);
            console.log(`Health check: http://localhost:${PORT}/api/health`);
            console.log(`Rate limiting: Enhanced for testing (10k requests/window, localhost bypass)`);
        });
    })
    .catch(error => {
        console.error("Errore durante l'inizializzazione del database:", error);
        process.exit(1);
    });

// Funzione per creare utente admin di default
async function createDefaultAdmin() {
    try {
        const { User, UserRole } = await import('./entity/User');
        const bcrypt = await import('bcryptjs');
        
        const userRepository = AppDataSource.getRepository(User);
        const adminExists = await userRepository.findOne({ 
            where: { email: 'admin@crm.local' } 
        });
        
        if (!adminExists) {
            const hashedPassword = await bcrypt.default.hash('admin123', 10);
            
            const admin = new User();
            admin.email = 'admin@crm.local';
            admin.password = hashedPassword;
            admin.firstName = 'Admin';
            admin.lastName = 'CRM';
            admin.role = UserRole.ADMIN;
            
            await userRepository.save(admin);
            console.log('Utente admin creato:');
            console.log('Email: admin@crm.local');
            console.log('Password: admin123');
        }
    } catch (error) {
        console.error('Errore nella creazione utente admin:', error);
    }
}

export default app;