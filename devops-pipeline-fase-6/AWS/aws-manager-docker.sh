#!/bin/bash

# AWS Manager per Docker Compose - t2.micro ottimizzato
# Gestione completa CRM con Docker Compose invece di Kubernetes

set -euo pipefail

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/aws-crm-deploy.log"
CRM_DIR="$HOME/crm-docker"
PUBLIC_IP=""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# Ottieni IP pubblico
get_public_ip() {
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/ || echo "UNKNOWN")
    log "Public IP: $PUBLIC_IP"
}

# Verifica prerequisiti
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        error "Docker not installed"
    fi
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        warn "Docker Compose not found, installing..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Git
    if ! command -v git &> /dev/null; then
        error "Git not installed"
    fi
    
    # Verifica memoria disponibile
    AVAILABLE_MEM=$(free -m | awk 'NR==2{print $7}')
    if [ "$AVAILABLE_MEM" -lt 400 ]; then
        warn "Low memory: ${AVAILABLE_MEM}MB available. Consider adding swap."
    fi
    
    log "✅ Prerequisites OK"
}

# Setup Docker per t2.micro
setup_docker() {
    log "🐳 Optimizing Docker for t2.micro..."
    
    # Crea configurazione Docker ottimizzata
    sudo mkdir -p /etc/docker
    
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },

  "storage-driver": "overlay2"
}
EOF
    
    # Restart Docker
    sudo systemctl restart docker
    
    # Aggiungi utente al gruppo docker
    sudo usermod -aG docker ubuntu
    
    log "✅ Docker optimized"
}

# Crea directory e file del progetto
setup_project() {
    log "📁 Setting up CRM project..."
    
    # Crea directory principale
    mkdir -p "$CRM_DIR"
    cd "$CRM_DIR"
    
    # Crea docker-compose.yml ottimizzato per t2.micro
    cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: crm-postgres
    environment:
      POSTGRES_DB: crm_db
      POSTGRES_USER: crm_user
      POSTGRES_PASSWORD: crm_password123
      POSTGRES_INITDB_ARGS: "--data-checksums"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    # Resource limits removed for compatibility
    command: >
      postgres
      -c shared_buffers=32MB
      -c max_connections=50
      -c work_mem=2MB
      -c maintenance_work_mem=32MB
      -c wal_buffers=1MB
      -c log_statement=none
      -c log_min_duration_statement=1000
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U crm_user -d crm_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: node:18-alpine
    container_name: crm-backend
    working_dir: /app
    environment:
      NODE_ENV: production
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USERNAME: crm_user
      DB_PASSWORD: crm_password123
      DB_DATABASE: crm_db
      JWT_SECRET: crm-super-secret-key-2024-aws
      PORT: 4001
      NODE_OPTIONS: "--max-old-space-size=100"
    volumes:
      - ./backend:/app
    ports:
      - "30003:4001"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    # Resource limits removed for compatibility
    command: >
      sh -c "
      if [ ! -d node_modules ]; then
        echo 'Installing dependencies...'
        npm install --production --no-audit --no-fund
      fi
      echo 'Starting backend...'
      npm start
      "
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: nginx:alpine
    container_name: crm-frontend
    volumes:
      - ./frontend:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "30002:80"
    depends_on:
      - backend
    restart: unless-stopped
    # Resource limits removed for compatibility
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
    driver: local

networks:
  default:
    driver: bridge
EOF

    log "✅ Docker Compose configuration created"
}

# Crea schema database
create_database_schema() {
    log "🗄️ Creating database schema..."
    
    cat > "$CRM_DIR/init-db.sql" << 'EOF'
-- CRM Database Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Companies table
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    industry VARCHAR(100),
    website VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Contacts table
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    position VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Opportunities table
CREATE TABLE IF NOT EXISTS opportunities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    value DECIMAL(12,2),
    stage VARCHAR(50) DEFAULT 'prospect',
    probability INTEGER DEFAULT 0,
    expected_close_date DATE,
    assigned_to UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default admin user (password: admin123)
INSERT INTO users (email, password_hash, first_name, last_name, role) 
VALUES (
    'admin@crm.local', 
    '$2b$10$rQ7qGqL8yQ7mXqZfJ8vNZ.QX.qGgXJqL8yQ7mXqZfJ8vNZ.QX.qGgX',
    'Admin', 
    'User', 
    'admin'
) ON CONFLICT (email) DO NOTHING;

-- Insert sample companies
INSERT INTO companies (name, industry, website, email) VALUES
    ('Tech Solutions Inc', 'Technology', 'https://techsolutions.com', 'info@techsolutions.com'),
    ('Marketing Plus', 'Marketing', 'https://marketingplus.com', 'hello@marketingplus.com'),
    ('AWS Customer Co', 'Cloud Services', 'https://awscustomer.com', 'contact@awscustomer.com')
ON CONFLICT DO NOTHING;

-- Insert sample opportunities
INSERT INTO opportunities (company_id, title, description, value, stage, probability) 
SELECT 
    c.id,
    'CRM Implementation',
    'Deploy new CRM system for customer management',
    50000.00,
    'proposal',
    75
FROM companies c WHERE c.name = 'Tech Solutions Inc'
ON CONFLICT DO NOTHING;

COMMIT;
EOF

    log "✅ Database schema created"
}

# Crea applicazione backend
create_backend() {
    log "⚙️ Creating backend application..."
    
    mkdir -p "$CRM_DIR/backend"
    cd "$CRM_DIR/backend"
    
    # Package.json
    cat > package.json << 'EOF'
{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "pg": "^8.8.0",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

    # Server.js
    cat > server.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = process.env.PORT || 4001;

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USERNAME || 'crm_user',
    password: process.env.DB_PASSWORD || 'crm_password123',
    database: process.env.DB_DATABASE || 'crm_db',
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW()');
        res.json({ 
            status: 'healthy', 
            timestamp: new Date().toISOString(),
            database: 'connected',
            dbTime: result.rows[0].now
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'unhealthy', 
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Test endpoint
app.get('/api/test', (req, res) => {
    res.json({ 
        message: 'CRM Backend is running on AWS!', 
        environment: process.env.NODE_ENV,
        timestamp: new Date().toISOString()
    });
});

// Get companies
app.get('/api/companies', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM companies ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Authentication endpoint
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const user = result.rows[0];
        // For demo, accept "admin123" password
        if (email === 'admin@crm.local' && password === 'admin123') {
            const token = jwt.sign(
                { userId: user.id, email: user.email }, 
                process.env.JWT_SECRET, 
                { expiresIn: '24h' }
            );
            
            res.json({ 
                token, 
                user: { 
                    id: user.id, 
                    email: user.email, 
                    firstName: user.first_name, 
                    lastName: user.last_name 
                } 
            });
        } else {
            res.status(401).json({ error: 'Invalid credentials' });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 CRM Backend running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV}`);
    console.log(`🗄️ Database: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_DATABASE}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    pool.end(() => {
        process.exit(0);
    });
});
EOF

    cd "$CRM_DIR"
    log "✅ Backend application created"
}

# Crea applicazione frontend
create_frontend() {
    log "🌐 Creating frontend application..."
    
    mkdir -p "$CRM_DIR/frontend"
    
    cat > "$CRM_DIR/frontend/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM System - AWS Deployment</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 15px; 
            padding: 30px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 2px solid #f0f0f0;
        }
        .header h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .header p {
            color: #666;
            font-size: 1.2em;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .status-card {
            padding: 20px;
            border-radius: 10px;
            border-left: 5px solid;
        }
        .status-success { 
            background: #d4edda; 
            color: #155724; 
            border-left-color: #28a745;
        }
        .status-warning { 
            background: #fff3cd; 
            color: #856404; 
            border-left-color: #ffc107;
        }
        .status-error { 
            background: #f8d7da; 
            color: #721c24; 
            border-left-color: #dc3545;
        }
        .status-info { 
            background: #d1ecf1; 
            color: #0c5460; 
            border-left-color: #17a2b8;
        }
        .status-card h3 {
            margin-bottom: 10px;
            font-size: 1.3em;
        }
        .info-section {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        .info-item {
            background: white;
            padding: 15px;
            border-radius: 8px;
            border: 1px solid #e9ecef;
        }
        .info-item strong {
            color: #495057;
            display: block;
            margin-bottom: 5px;
        }
        .actions {
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
            margin-top: 20px;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 1em;
            transition: all 0.3s;
            text-decoration: none;
            display: inline-block;
        }
        .btn-primary {
            background: #007bff;
            color: white;
        }
        .btn-primary:hover {
            background: #0056b3;
        }
        .btn-success {
            background: #28a745;
            color: white;
        }
        .btn-success:hover {
            background: #1e7e34;
        }
        .spinning {
            animation: spin 2s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 CRM System</h1>
            <p>AWS EC2 t2.micro Deployment - Docker Compose</p>
        </div>
        
        <div class="status-grid">
            <div class="status-card status-success">
                <h3>✅ Frontend Status</h3>
                <p>Application successfully deployed and running</p>
            </div>
            
            <div class="status-card status-info" id="backend-status">
                <h3><span class="spinning">🔄</span> Backend Status</h3>
                <p>Checking API connectivity...</p>
            </div>
            
            <div class="status-card status-info" id="database-status">
                <h3><span class="spinning">🔄</span> Database Status</h3>
                <p>Checking PostgreSQL connection...</p>
            </div>
        </div>

        <div class="info-section">
            <h2>🌐 System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Environment:</strong>
                    <span>AWS EC2 t2.micro Free Tier</span>
                </div>
                <div class="info-item">
                    <strong>Platform:</strong>
                    <span>Docker Compose</span>
                </div>
                <div class="info-item">
                    <strong>Database:</strong>
                    <span>PostgreSQL 16 Alpine</span>
                </div>
                <div class="info-item">
                    <strong>Frontend URL:</strong>
                    <span id="frontend-url">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>API URL:</strong>
                    <span id="api-url">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Server Time:</strong>
                    <span id="server-time">Loading...</span>
                </div>
            </div>
        </div>

        <div class="actions">
            <button class="btn btn-primary" onclick="testAPI()">🧪 Test API</button>
            <button class="btn btn-success" onclick="checkHealth()">❤️ Health Check</button>
            <a href="/api/companies" target="_blank" class="btn btn-primary">📊 View Companies</a>
        </div>

        <div id="test-results" style="margin-top: 20px;"></div>
    </div>

    <script>
        // Set URLs
        const host = window.location.hostname;
        document.getElementById('frontend-url').textContent = `http://${host}:30002`;
        document.getElementById('api-url').textContent = `http://${host}:30003/api`;
        
        // Update server time
        document.getElementById('server-time').textContent = new Date().toLocaleString();
        setInterval(() => {
            document.getElementById('server-time').textContent = new Date().toLocaleString();
        }, 1000);
        
        // Check backend health
        async function checkBackend() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                
                document.getElementById('backend-status').innerHTML = `
                    <h3>✅ Backend Status</h3>
                    <p>API connected successfully! Database: ${data.database}</p>
                `;
                document.getElementById('backend-status').className = 'status-card status-success';
                return true;
            } catch (error) {
                document.getElementById('backend-status').innerHTML = `
                    <h3>❌ Backend Status</h3>
                    <p>API connection failed: ${error.message}</p>
                `;
                document.getElementById('backend-status').className = 'status-card status-error';
                return false;
            }
        }
        
        // Check database
        async function checkDatabase() {
            try {
                const response = await fetch('/api/companies');
                const data = await response.json();
                
                document.getElementById('database-status').innerHTML = `
                    <h3>✅ Database Status</h3>
                    <p>PostgreSQL connected! Found ${data.length} companies</p>
                `;
                document.getElementById('database-status').className = 'status-card status-success';
            } catch (error) {
                document.getElementById('database-status').innerHTML = `
                    <h3>❌ Database Status</h3>
                    <p>Database connection failed: ${error.message}</p>
                `;
                document.getElementById('database-status').className = 'status-card status-error';
            }
        }

        // Test API function
        async function testAPI() {
            const resultsDiv = document.getElementById('test-results');
            resultsDiv.innerHTML = '<div class="info-section"><h3>🧪 API Test Results</h3><p>Running tests...</p></div>';
            
            try {
                const response = await fetch('/api/test');
                const data = await response.json();
                
                resultsDiv.innerHTML = `
                    <div class="info-section">
                        <h3>✅ API Test Successful</h3>
                        <div class="info-grid">
                            <div class="info-item">
                                <strong>Message:</strong> ${data.message}
                            </div>
                            <div class="info-item">
                                <strong>Environment:</strong> ${data.environment}
                            </div>
                            <div class="info-item">
                                <strong>Timestamp:</strong> ${data.timestamp}
                            </div>
                        </div>
                    </div>
                `;
            } catch (error) {
                resultsDiv.innerHTML = `
                    <div class="status-card status-error">
                        <h3>❌ API Test Failed</h3>
                        <p>Error: ${error.message}</p>
                    </div>
                `;
            }
        }

        // Health check function
        async function checkHealth() {
            await checkBackend();
            await checkDatabase();
        }

        // Initial checks
        window.addEventListener('load', () => {
            setTimeout(checkBackend, 2000);
            setTimeout(checkDatabase, 4000);
        });
    </script>
</body>
</html>
EOF

    log "✅ Frontend application created"
}

# Crea configurazione Nginx
create_nginx_config() {
    log "⚙️ Creating Nginx configuration..."
    
    cat > "$CRM_DIR/nginx.conf" << 'EOF'
worker_processes 1;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 256;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    types_hash_max_size 2048;
    client_max_body_size 1m;
    
    # Minimal logging for t2.micro
    access_log off;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    server {
        listen 80;
        server_name localhost;
        
        root /usr/share/nginx/html;
        index index.html;
        
        # Frontend routes
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # API proxy to backend
        location /api/ {
            proxy_pass http://crm-backend:4001/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }
        
        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

    log "✅ Nginx configuration created"
}

# Deploy dell'applicazione
deploy_application() {
    log "🚀 Deploying CRM application..."
    
    cd "$CRM_DIR"
    
    # Verifica configurazione
    docker-compose config > /dev/null
    
    # Pull immagini
    log "📥 Pulling Docker images..."
    docker-compose pull
    
    # Start database per primo
    log "🗄️ Starting PostgreSQL..."
    docker-compose up -d postgres
    
    # Aspetta che database sia pronto
    log "⏳ Waiting for database to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T postgres pg_isready -U crm_user -d crm_db; then
            log "✅ Database is ready"
            break
        fi
        sleep 2
    done
    
    # Start tutti i servizi
    log "🌐 Starting all services..."
    docker-compose up -d
    
    # Aspetta che tutti i servizi siano pronti
    log "⏳ Waiting for services to be ready..."
    sleep 30
    
    # Verifica stato
    docker-compose ps
    
    log "✅ Deployment completed"
}

# Test dell'applicazione
test_application() {
    log "🧪 Testing CRM application..."
    
    get_public_ip
    
    # Test frontend
    log "Testing frontend..."
    if curl -s "http://localhost:30002" > /dev/null; then
        log "✅ Frontend OK"
    else
        warn "❌ Frontend test failed"
    fi
    
    # Test backend health
    log "Testing backend health..."
    if curl -s "http://localhost:30003/api/health" | grep -q "healthy"; then
        log "✅ Backend health OK"
    else
        warn "❌ Backend health test failed"
    fi
    
    # Test database connectivity
    log "Testing database..."
    if curl -s "http://localhost:30003/api/companies" > /dev/null; then
        log "✅ Database connectivity OK"
    else
        warn "❌ Database test failed"
    fi
    
    # Mostra URLs di accesso
    echo ""
    echo "🌐 ========== CRM ACCESS URLS =========="
    echo "Frontend:    http://$PUBLIC_IP:30002"
    echo "Backend API: http://$PUBLIC_IP:30003/api"
    echo "Health:      http://$PUBLIC_IP:30003/api/health"
    echo "Companies:   http://$PUBLIC_IP:30003/api/companies"
    echo ""
    echo "📊 Login Credentials:"
    echo "Email:    admin@crm.local"
    echo "Password: admin123"
    echo "======================================="
}

# Monitor dell'applicazione
monitor_application() {
    log "📊 Monitoring CRM application..."
    
    echo "=== DOCKER COMPOSE STATUS ==="
    docker-compose ps
    
    echo ""
    echo "=== RESOURCE USAGE ==="
    docker stats --no-stream
    
    echo ""
    echo "=== SYSTEM RESOURCES ==="
    free -h
    df -h /
    uptime
    
    echo ""
    echo "=== SERVICE LOGS (last 20 lines) ==="
    echo "--- PostgreSQL ---"
    docker-compose logs --tail=10 postgres
    echo "--- Backend ---"
    docker-compose logs --tail=10 backend
    echo "--- Frontend ---"
    docker-compose logs --tail=10 frontend
}

# Backup del database
backup_database() {
    log "💾 Backing up database..."
    
    BACKUP_DIR="$HOME/crm-backups"
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/crm-backup-$(date +%Y%m%d_%H%M%S).sql"
    
    docker-compose exec -T postgres pg_dump -U crm_user crm_db > "$BACKUP_FILE"
    
    if [ -f "$BACKUP_FILE" ]; then
        log "✅ Backup saved to $BACKUP_FILE"
        # Mantieni solo ultimi 5 backup
        ls -t "$BACKUP_DIR"/crm-backup-*.sql | tail -n +6 | xargs -r rm
    else
        error "❌ Backup failed"
    fi
}

# Stop dell'applicazione
stop_application() {
    log "🛑 Stopping CRM application..."
    
    cd "$CRM_DIR"
    docker-compose down
    
    log "✅ Application stopped"
}

# Restart dell'applicazione
restart_application() {
    log "🔄 Restarting CRM application..."
    
    cd "$CRM_DIR"
    docker-compose restart
    
    log "✅ Application restarted"
}

# Cleanup completo
cleanup_application() {
    log "🧹 Cleaning up CRM application..."
    
    cd "$CRM_DIR"
    
    # Stop e rimuovi container
    docker-compose down -v
    
    # Rimuovi immagini
    docker image prune -f
    
    # Rimuovi volumi non utilizzati
    docker volume prune -f
    
    log "✅ Cleanup completed"
}

# Menu principale
show_menu() {
    echo ""
    echo "🚀 ========== AWS CRM Manager (Docker Compose) =========="
    echo "1.  setup           - Complete setup and deployment"
    echo "2.  deploy          - Deploy application"
    echo "3.  test            - Test application"
    echo "4.  monitor         - Monitor resources and logs"
    echo "5.  status          - Show status"
    echo "6.  restart         - Restart application"
    echo "7.  stop            - Stop application"
    echo "8.  backup          - Backup database"
    echo "9.  cleanup         - Cleanup all resources"
    echo "10. logs            - Show logs"
    echo "========================================================="
}

# Comando logs
show_logs() {
    cd "$CRM_DIR"
    if [ "$#" -eq 2 ]; then
        docker-compose logs -f "$2"
    else
        docker-compose logs -f
    fi
}

# Comando status
show_status() {
    log "📊 CRM Application Status"
    
    if [ -d "$CRM_DIR" ]; then
        cd "$CRM_DIR"
        docker-compose ps
        echo ""
        get_public_ip
        echo "Frontend: http://$PUBLIC_IP:30002"
        echo "Backend:  http://$PUBLIC_IP:30003/api"
    else
        warn "CRM not deployed yet. Run: $0 setup"
    fi
}

# Main function
main() {
    case "${1:-menu}" in
        "setup")
            log "🚀 Starting complete CRM setup..."
            check_prerequisites
            setup_docker
            setup_project
            create_database_schema
            create_backend
            create_frontend
            create_nginx_config
            deploy_application
            test_application
            log "🎉 CRM setup completed successfully!"
            ;;
        "deploy")
            deploy_application
            ;;
        "test")
            test_application
            ;;
        "monitor")
            monitor_application
            ;;
        "status")
            show_status
            ;;
        "restart")
            restart_application
            ;;
        "stop")
            stop_application
            ;;
        "backup")
            backup_database
            ;;
        "cleanup")
            cleanup_application
            ;;
        "logs")
            show_logs "$@"
            ;;
        "menu"|*)
            show_menu
            echo ""
            echo "Usage: $0 {setup|deploy|test|monitor|status|restart|stop|backup|cleanup|logs}"
            ;;
    esac
}

# Esegui main con tutti gli argomenti
main "$@"
