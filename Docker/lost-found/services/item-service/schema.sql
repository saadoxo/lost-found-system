CREATE TABLE IF NOT EXISTS items (
  id          SERIAL PRIMARY KEY,
  type        VARCHAR(10) NOT NULL CHECK (type IN ('lost','found')),
  title       VARCHAR(200) NOT NULL,
  description TEXT,
  category    VARCHAR(20) NOT NULL,
  location    VARCHAR(300) NOT NULL,
  date        DATE NOT NULL,
  image_key   VARCHAR(500),
  status      VARCHAR(20) NOT NULL DEFAULT 'open',
  user_id     INTEGER NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_items_type     ON items(type);
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category);
CREATE INDEX IF NOT EXISTS idx_items_user_id  ON items(user_id);
CREATE INDEX IF NOT EXISTS idx_items_status   ON items(status);