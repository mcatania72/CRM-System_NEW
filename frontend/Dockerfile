# Frontend Dockerfile
FROM node:18-alpine as builder

# Imposta la directory di lavoro
WORKDIR /app

# Copia i file package.json
COPY package*.json ./

# Installa le dipendenze
RUN npm ci

# Copia il codice sorgente
COPY . .

# Build dell'applicazione React
RUN npm run build

# Stage di produzione con Nginx
FROM nginx:alpine

# Copia i file buildati
COPY --from=builder /app/dist /usr/share/nginx/html

# Copia la configurazione nginx personalizzata
COPY nginx.conf /etc/nginx/nginx.conf

# Espone la porta 80
EXPOSE 80

# Comando di avvio
CMD ["nginx", "-g", "daemon off;"]