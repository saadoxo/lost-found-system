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
    { expiresIn: '15m', algorithm: 'HS256' }
  );

  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh' },
    REFRESH_SECRET,
    { expiresIn: '7d', algorithm: 'HS256' }
  );

  return { accessToken, refreshToken };
};

exports.verifyAccess = (token) => {
  return jwt.verify(token, ACCESS_SECRET, { algorithms: ['HS256'] });
};

exports.verifyRefresh = (token) => {
  return jwt.verify(token, REFRESH_SECRET, { algorithms: ['HS256'] });
};
