const jwt = require('jsonwebtoken');

const ACCESS_SECRET  = process.env.JWT_ACCESS_SECRET;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;

if (!ACCESS_SECRET || !REFRESH_SECRET) {
  console.error('FATAL: JWT secrets not set. Check JWT_ACCESS_SECRET and JWT_REFRESH_SECRET env vars.');
  process.exit(1);
}

exports.generateTokenPair = (userId, email, role) => {
  const accessToken = jwt.sign(
    { sub: userId, email, role, type: 'access' },
    ACCESS_SECRET,
    // Always specify algorithm — prevents the alg:none attack
    { expiresIn: '15m', algorithm: 'HS256' }
  );

  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh' },
    // Separate secret for refresh tokens — prevents cross-token type confusion attacks
    REFRESH_SECRET,
    { expiresIn: '7d', algorithm: 'HS256' }
  );

  return { accessToken, refreshToken };
};

exports.verifyAccess = (token) => {
  // Always pass algorithms array — never let the library trust the token's alg header
  return jwt.verify(token, ACCESS_SECRET, { algorithms: ['HS256'] });
};

exports.verifyRefresh = (token) => {
  return jwt.verify(token, REFRESH_SECRET, { algorithms: ['HS256'] });
};
