const express   = require('express');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const authRoutes = require('./routes/auth');

const app = express();

app.use(helmet());
app.use(express.json({ limit: '10kb' }));
app.set('trust proxy', 1);

// 10 attempts per 15 minutes — applied only to auth routes
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'auth-service' });
});

app.get('/ready', async (req, res) => {
  const db = require('./config/database');
  try {
    await db.query('SELECT 1');
    res.json({ status: 'ready', service: 'auth-service' });
  } catch {
    res.status(503).json({ status: 'not ready', reason: 'database unreachable' });
  }
});

app.use('/auth', authLimiter, authRoutes);

app.use((err, req, res, next) => {
  console.error(JSON.stringify({ level: 'error', event: 'unhandled_error', error: err.message }));
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
