#!/bin/bash

# ============================================
# Deploy Testing - Services Module
# FASE 5: Avvio servizi testing
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_services() {
    echo -e "${BLUE}[SERVICES]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SERVICES: $1" >> ~/deploy-testing.log
}

log_services "Avvio servizi testing..."

# Set testing environment
export NODE_ENV=test
export TEST_MODE=true

# Backend testing (port 3101)
log_services "Avvio backend testing su porta 3101..."
cd "$HOME/devops/CRM-System/backend" || exit 1

# Kill existing testing processes
pkill -f "node.*3101" 2>/dev/null || true
pkill -f "npm.*test.*backend" 2>/dev/null || true

# Start backend in test mode
PORT=3101 npm run dev > "$HOME/backend-testing.log" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$HOME/backend-testing.pid"

# Wait for backend
log_services "Attesa backend startup..."
for i in {1..30}; do
    if curl -s http://localhost:3101/api/health >/dev/null 2>&1; then
        log_services "✅ Backend testing avviato (PID: $BACKEND_PID)"
        break
    fi
    sleep 1
done

# Frontend testing (port 3100)  
log_services "Avvio frontend testing su porta 3100..."
cd "$HOME/devops/CRM-System/frontend" || exit 1

# Kill existing testing processes
pkill -f "vite.*3100" 2>/dev/null || true
pkill -f "npm.*test.*frontend" 2>/dev/null || true

# Update vite config for testing port
cat > vite.config.test.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3100,
    host: true
  },
  define: {
    'process.env.VITE_API_URL': '"http://localhost:3101"'
  }
})
EOF

# Start frontend in test mode
VITE_CONFIG=vite.config.test.js npm run dev > "$HOME/frontend-testing.log" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$HOME/frontend-testing.pid"

# Wait for frontend
log_services "Attesa frontend startup..."
for i in {1..30}; do
    if curl -s http://localhost:3100 >/dev/null 2>&1; then
        log_services "✅ Frontend testing avviato (PID: $FRONTEND_PID)"
        break
    fi
    sleep 1
done

log_services "✅ Servizi testing avviati con successo!"
log_services "Backend: http://localhost:3101"
log_services "Frontend: http://localhost:3100"

exit 0