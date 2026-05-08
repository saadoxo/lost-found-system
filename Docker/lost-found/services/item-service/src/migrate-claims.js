const { Pool } = require('pg');

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl:      { rejectUnauthorized: false }
});

pool.query(`
  CREATE TABLE IF NOT EXISTS claims (
    id           SERIAL PRIMARY KEY,
    item_id      INTEGER NOT NULL,
    claimant_id  INTEGER NOT NULL,
    message      TEXT,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
  );
  CREATE INDEX IF NOT EXISTS idx_claims_item_id     ON claims(item_id);
  CREATE INDEX IF NOT EXISTS idx_claims_claimant_id ON claims(claimant_id);
`)
.then(() => { console.log('CLAIMS MIGRATION DONE'); process.exit(0); })
.catch(e => { console.error(e.message); process.exit(1); });