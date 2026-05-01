const pool = require('./config/database');

async function run() {
  try {
    console.log("STARTING MIGRATION");

    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'user',
        status VARCHAR(20) NOT NULL DEFAULT 'active',
        refresh_token_hash VARCHAR(255),
        last_login TIMESTAMP,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS items (
        id SERIAL PRIMARY KEY,
        type VARCHAR(10) NOT NULL,
        title VARCHAR(200) NOT NULL,
        description TEXT,
        category VARCHAR(20) NOT NULL,
        location VARCHAR(300) NOT NULL,
        date DATE NOT NULL,
        image_key VARCHAR(500),
        status VARCHAR(20) NOT NULL DEFAULT 'open',
        user_id INTEGER NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );
    `);

    console.log("MIGRATION DONE");
    process.exit(0);
  } catch (err) {
    console.error("MIGRATION ERROR:", err);
    process.exit(1);
  }
}

run();