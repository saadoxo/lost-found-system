const db    = require('../config/database');
const queue = require('../services/queue');

exports.listItems = async (req, res) => {
  const { type, category, location, dateFrom, dateTo, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * Math.min(limit, 100);

  try {
    let conditions = ['status != $1'];
    let params     = ['closed'];
    let idx        = 2;

    if (type)     { conditions.push(`type = $${idx++}`);              params.push(type); }
    if (category) { conditions.push(`category = $${idx++}`);          params.push(category); }
    if (location) { conditions.push(`location ILIKE $${idx++}`);      params.push(`%${location}%`); }
    if (dateFrom) { conditions.push(`date >= $${idx++}`);             params.push(dateFrom); }
    if (dateTo)   { conditions.push(`date <= $${idx++}`);             params.push(dateTo); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await db.query(`SELECT COUNT(*) FROM items ${where}`, params);
    const total       = parseInt(countResult.rows[0].count);

    const items = await db.query(
      `SELECT * FROM items ${where} ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, Math.min(limit, 100), offset]
    );

    res.json({
      items: items.rows,
      total,
      page:  parseInt(page),
      pages: Math.ceil(total / limit)
    });
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', event: 'list_items_error', error: err.message }));
    res.status(500).json({ error: 'Failed to fetch items' });
  }
};

exports.createItem = async (req, res) => {
  const { type, title, description, category, location, date, imageKey } = req.body;
  const userId = req.user.sub;

  try {
    const result = await db.query(
      `INSERT INTO items (type, title, description, category, location, date, image_key, user_id, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'open',NOW(),NOW())
       RETURNING *`,
      [type, title, description || null, category, location, date, imageKey || null, userId]
    );

    const item = result.rows[0];

    // Publish to SQS to trigger the matching pipeline
    await queue.publishItemCreated(item);

    console.log(JSON.stringify({ level: 'info', event: 'item_created', itemId: item.id, userId }));
    res.status(201).json(item);

  } catch (err) {
    console.error(JSON.stringify({ level: 'error', event: 'create_item_error', error: err.message }));
    res.status(500).json({ error: 'Failed to create item' });
  }
};

exports.getItem = async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM items WHERE id = $1', [req.params.id]);
    if (!result.rows.length) return res.status(404).json({ error: 'Item not found' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch item' });
  }
};

exports.updateItem = async (req, res) => {
  const { id } = req.params;
  const userId  = req.user.sub;

  try {
    const existing = await db.query('SELECT * FROM items WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ error: 'Item not found' });
    if (existing.rows[0].user_id !== userId) return res.status(403).json({ error: 'Not your item' });

    const fields  = req.body;
    const columns = Object.keys(fields).map((k, i) => `${k} = $${i + 2}`).join(', ');
    const values  = Object.values(fields);

    const result = await db.query(
      `UPDATE items SET ${columns}, updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id, ...values]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update item' });
  }
};

exports.deleteItem = async (req, res) => {
  const { id } = req.params;
  const userId  = req.user.sub;
  const role    = req.user.role;

  try {
    const existing = await db.query('SELECT * FROM items WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ error: 'Item not found' });
    if (existing.rows[0].user_id !== userId && role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized' });
    }
    await db.query('DELETE FROM items WHERE id = $1', [id]);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete item' });
  }
};