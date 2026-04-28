const express = require('express');
const helmet  = require('helmet');
const { Pool } = require('pg');

const app  = express();
const PORT = process.env.PORT || 3007;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: false
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'admin-service' }));
app.get('/ready',  async (req, res) => {
  try { await pool.query('SELECT 1'); res.json({ status: 'ready' }); }
  catch { res.status(503).json({ status: 'not ready' }); }
});

// Analytics dashboard endpoint
app.get('/admin/analytics', async (req, res) => {
  try {
    const [users, items, matches] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM users'),
      pool.query(`SELECT COUNT(*) total, COUNT(*) FILTER (WHERE status = 'open') open,
                  COUNT(*) FILTER (WHERE status = 'matched') matched,
                  COUNT(*) FILTER (WHERE type = 'lost') lost,
                  COUNT(*) FILTER (WHERE type = 'found') found FROM items`),
      pool.query('SELECT COUNT(*) FROM items WHERE status = $1', ['matched'])
    ]);

    res.json({
      totalUsers:   parseInt(users.rows[0].count),
      totalItems:   parseInt(items.rows[0].total),
      openItems:    parseInt(items.rows[0].open),
      matchedItems: parseInt(items.rows[0].matched),
      lostItems:    parseInt(items.rows[0].lost),
      foundItems:   parseInt(items.rows[0].found)
    });
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', error: err.message }));
    res.status(500).json({ error: 'Failed to fetch analytics' });
  }
});

// List all users
app.get('/admin/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, name, role, status, created_at FROM users ORDER BY created_at DESC'
    );
    res.json({ users: result.rows, total: result.rows.length });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// List all items
app.get('/admin/items', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM items ORDER BY created_at DESC LIMIT 100'
    );
    res.json({ items: result.rows, total: result.rows.length });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch items' });
  }
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `admin-service listening on ${PORT}` }));
});