# Multi-stage build per Frontend React
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY frontend/ ./

# Install ALL dependencies (including devDependencies for build)
RUN if [ -f "package-lock.json" ]; then npm ci; else npm install; fi

# Build React application
RUN npm run build

# Production stage con nginx
FROM nginx:alpine AS production

# Install curl per health checks
RUN apk add --no-cache curl

# Copy custom nginx config
COPY devops-pipeline-fase-2/containers/frontend/nginx.conf /etc/nginx/nginx.conf

# Copy built application
COPY --from=builder /app/dist /usr/share/nginx/html

# Create non-root user (use existing nginx group)
RUN adduser -S nginx-user -u 1001 -G nginx

# Set permissions
RUN chown -R nginx-user:nginx /usr/share/nginx/html && \
    chown -R nginx-user:nginx /var/cache/nginx && \
    chown -R nginx-user:nginx /var/log/nginx && \
    chown -R nginx-user:nginx /etc/nginx/conf.d && \
    chmod -R 755 /var/cache/nginx /var/log/nginx

# Switch to non-root user
USER nginx-user

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]