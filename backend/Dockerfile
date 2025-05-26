# Dockerfile per il Backend
FROM node:18-alpine

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

# Espone la porta
EXPOSE 3001

# Comando di avvio
CMD ["npm", "start"]