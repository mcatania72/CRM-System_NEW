# Backend Dockerfile - Multi-stage build
# FASE 2: Containerizzazione Completa

# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy all backend files
COPY backend/ ./

# Install dependencies
RUN npm ci

# Build TypeScript (se possibile, altrimenti skipa)
RUN npm run build || echo "Build failed, using source files"

# Stage 2: Production
FROM node:18-alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

# Create app user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

WORKDIR /app

# Copy backend files
COPY backend/ ./

# Install production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy built files if they exist, otherwise use src
COPY --from=builder /app/dist ./dist 2>/dev/null || echo "No build artifacts, using dev mode"

# Create data directory for SQLite
RUN mkdir -p /app/data && chown -R nodejs:nodejs /app/data

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# Start application (try production first, fallback to dev)
CMD if [ -d "./dist" ]; then npm start; else npm run dev; fi