FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3006

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3006/health || exit 1

CMD ["node", "src/index.js"]
