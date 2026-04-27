const bcrypt      = require('bcrypt');
const db          = require('../config/database');
const tokenService = require('../services/token');

const BCRYPT_ROUNDS = 12;

exports.register = async (req, res) => {
  const { email, password, name } = req.body;

  try {
    // Check if email already exists
    const existing = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const result = await db.query(
      `INSERT INTO users (email, password_hash, name, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())
       RETURNING id, email, name, role`,
      [email, hash, name]
    );

    console.log(JSON.stringify({
      level: 'info', event: 'user_registered', userId: result.rows[0].id
    }));

    res.status(201).json({ user: result.rows[0] });

  } catch (err) {
    console.error(JSON.stringify({ level: 'error', event: 'register_error', error: err.message }));
    res.status(500).json({ error: 'Registration failed' });
  }
};

exports.login = async (req, res) => {
  const { email, password } = req.body;

  try {
    const result = await db.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    // SECURITY: uniform error message for both user-not-found and wrong-password
    // This prevents user enumeration — attacker cannot tell which case triggered
    if (result.rows.length === 0) {
      // SECURITY: run a fake bcrypt hash to equalise response time
      // Without this, a missing user returns instantly (timing attack)
      await bcrypt.hash(password, BCRYPT_ROUNDS);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    if (user.status === 'suspended' || user.status === 'banned') {
      return res.status(403).json({ error: 'Account suspended' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);

    if (!valid) {
      console.log(JSON.stringify({
        level: 'warn', event: 'login_failed', email, ip: req.ip
      }));
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const tokens = tokenService.generateTokenPair(user.id, user.email, user.role);

    // Store hashed refresh token — allows us to invalidate it on logout
    const refreshHash = await bcrypt.hash(tokens.refreshToken, 10);
    await db.query(
      'UPDATE users SET refresh_token_hash = $1, last_login = NOW() WHERE id = $2',
      [refreshHash, user.id]
    );

    console.log(JSON.stringify({
      level: 'info', event: 'login_success', userId: user.id
    }));

    res.json({
      accessToken:  tokens.accessToken,
      refreshToken: tokens.refreshToken
    });

  } catch (err) {
    console.error(JSON.stringify({ level: 'error', event: 'login_error', error: err.message }));
    res.status(500).json({ error: 'Login failed' });
  }
};

exports.refresh = async (req, res) => {
  const { refreshToken } = req.body;

  try {
    const decoded = tokenService.verifyRefresh(refreshToken);

    if (decoded.type !== 'refresh') {
      return res.status(401).json({ error: 'Invalid token type' });
    }

    const result = await db.query(
      'SELECT * FROM users WHERE id = $1',
      [decoded.sub]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    // Verify the stored hash matches — catches token reuse after logout
    if (!user.refresh_token_hash) {
      return res.status(401).json({ error: 'Token revoked' });
    }

    const valid = await bcrypt.compare(refreshToken, user.refresh_token_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Token revoked' });
    }

    // Issue a new pair and rotate the stored refresh token
    const tokens = tokenService.generateTokenPair(user.id, user.email, user.role);
    const newRefreshHash = await bcrypt.hash(tokens.refreshToken, 10);

    await db.query(
      'UPDATE users SET refresh_token_hash = $1 WHERE id = $2',
      [newRefreshHash, user.id]
    );

    res.json({
      accessToken:  tokens.accessToken,
      refreshToken: tokens.refreshToken
    });

  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Refresh token expired. Please log in again.' });
    }
    res.status(401).json({ error: 'Invalid refresh token' });
  }
};

exports.logout = async (req, res) => {
  try {
    // Clear the refresh token hash — this invalidates all future refresh attempts
    await db.query(
      'UPDATE users SET refresh_token_hash = NULL WHERE id = $1',
      [req.user.sub]
    );

    console.log(JSON.stringify({
      level: 'info', event: 'logout', userId: req.user.sub
    }));

    res.json({ message: 'Logged out successfully' });

  } catch (err) {
    res.status(500).json({ error: 'Logout failed' });
  }
};

exports.me = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT id, email, name, role, created_at FROM users WHERE id = $1',
      [req.user.sub]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);

  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
};
