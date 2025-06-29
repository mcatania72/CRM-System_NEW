# Dockerfile per il Backend
FROM node:18-alpine

# Installa wget per l'healthcheck
RUN apk add --no-cache wget

# Imposta la directory di lavoro
WORKDIR /app

# Copia i file package.json
COPY package*.json ./

# Installa TUTTE le dipendenze (incluse devDependencies per il build)
RUN npm ci

# Copia il codice sorgente
COPY . .

# Compila TypeScript
RUN npm run build

# Rimuovi le devDependencies dopo il build per ridurre la dimensione
RUN npm prune --production

# Copia e imposta i permessi per lo script di healthcheck
COPY healthcheck.sh /
RUN chmod +x /healthcheck.sh

# Espone la porta
EXPOSE 4001

# Comando di avvio
CMD ["npm", "start"]