FROM node:20-alpine

RUN apk add --no-cache python3 make g++

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src/ ./src/

RUN mkdir -p data/certificates data/profiles data/p8keys data/uploads

EXPOSE 3006

ENV NODE_ENV=production

CMD ["node", "src/app.js"]
