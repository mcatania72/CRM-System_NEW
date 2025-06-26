# Multi-stage build per Backend Node.js
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY backend/ ./

# Install ALL dependencies (including devDependencies for build)
RUN if [ -f "package-lock.json" ]; then npm ci; else npm install; fi

# Try to build TypeScript (fallback handled in production stage)
RUN npm run build || echo "Build failed, will use dev mode"

# Production stage
FROM node:18-alpine AS production

# Install system dependencies
RUN apk add --no-cache \
    curl \
    sqlite \
    && addgroup -g 1001 -S nodejs \
    && adduser -S crm-user -u 1001

WORKDIR /app

# Copy package files and install ONLY production dependencies
COPY backend/package*.json ./
RUN if [ -f "package-lock.json" ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force

# Copy built application or source
COPY --from=builder /app/ ./

# Create data directory for SQLite
RUN mkdir -p /app/data && chown -R crm-user:nodejs /app

# Switch to non-root user
USER crm-user

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# Smart start: try production, fallback to dev
CMD ["sh", "-c", "if [ -d './dist' ] && [ -f './dist/app.js' ]; then npm start; else npm run dev; fi"]