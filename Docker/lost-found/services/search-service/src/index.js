const express    = require('express');
const helmet     = require('helmet');
const { Pool }   = require('pg');

const app  = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));
app.set('trust proxy', 1);

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'search-service' }));
app.get('/ready',  async (req, res) => {
  try { await pool.query('SELECT 1'); res.json({ status: 'ready', service: 'search-service' }); }
  catch { res.status(503).json({ status: 'not ready' }); }
});

app.get('/search', async (req, res) => {
  const { q, type, category, page = 1, limit = 20 } = req.query;

  if (!q || q.length < 2) {
    return res.status(400).json({ error: 'Query must be at least 2 characters' });
  }

  try {
    const offset     = (page - 1) * Math.min(limit, 50);
    let conditions   = ["(title ILIKE $1 OR description ILIKE $1)", "status != 'closed'"];
    let params       = [`%${q}%`];
    let idx          = 2;

    if (type)     { conditions.push(`type = $${idx++}`);     params.push(type); }
    if (category) { conditions.push(`category = $${idx++}`); params.push(category); }

    const where = `WHERE ${conditions.join(' AND ')}`;

    const countResult = await pool.query(`SELECT COUNT(*) FROM items ${where}`, params);
    const total       = parseInt(countResult.rows[0].count);

    const results = await pool.query(
      `SELECT * FROM items ${where} ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, Math.min(limit, 50), offset]
    );

    res.json({
      results: results.rows,
      total,
      page:  parseInt(page),
      pages: Math.ceil(total / limit),
      query: q
    });
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', error: err.message }));
    res.status(500).json({ error: 'Search failed' });
  }
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `search-service listening on ${PORT}` }));
});
