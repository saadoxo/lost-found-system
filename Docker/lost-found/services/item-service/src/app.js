const express   = require('express');
const helmet    = require('helmet');
const itemRoutes = require('./routes/item');

const app = express();

app.use(helmet());
app.use(express.json({ limit: '10kb' }));
app.set('trust proxy', 1);

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'item-service' }));
app.get('/items/health', (req, res) => res.json({ status: 'ok', service: 'item-service' }));
app.get('/ready',  async (req, res) => {
  const db = require('./config/database');
  try { await db.query('SELECT 1'); res.json({ status: 'ready' }); }
  catch { res.status(503).json({ status: 'not ready' }); }
});

app.use('/items', itemRoutes);

app.use((err, req, res, next) => {
  console.error(JSON.stringify({ level: 'error', error: err.message }));
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;