const express = require('express');
const helmet  = require('helmet');

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

// Health check — used by ECS, ALB, and docker-compose
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'auth-service' });
});

// Readiness check — will verify DB connection in Phase 3
app.get('/ready', (req, res) => {
  res.json({ status: 'ready', service: 'auth-service' });
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `auth-service listening on ${PORT}` }));
});
