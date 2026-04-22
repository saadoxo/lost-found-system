FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# npm install instead of npm ci — ci requires a lockfile to already exist
# Once you run npm install once, a package-lock.json is generated,
# and you can switch back to npm ci for reproducible installs in CI/CD
RUN npm install --omit=dev

COPY src/ ./src/

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3006

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3006/health || exit 1

CMD ["node", "src/index.js"]
