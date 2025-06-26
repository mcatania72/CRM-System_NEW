# Frontend Dockerfile - Multi-stage build
# FASE 2: Containerizzazione Completa

# Stage 1: Build React application
FROM node:18-alpine AS builder

WORKDIR /app

# Copy all frontend files
COPY frontend/ ./

# Install dependencies
RUN npm ci

# Build application
RUN npm run build

# Stage 2: Production with nginx
FROM nginx:alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy built application
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY devops-pipeline-fase-2/containers/frontend/nginx.conf /etc/nginx/nginx.conf

# Create non-root user
RUN addgroup -g 1001 -S nginx_user
RUN adduser -S nginx_user -u 1001

# Create necessary directories and set permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run \
    && chown -R nginx_user:nginx_user /var/cache/nginx /var/log/nginx /var/run \
    && chown -R nginx_user:nginx_user /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html

# Switch to non-root user
USER nginx_user

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]