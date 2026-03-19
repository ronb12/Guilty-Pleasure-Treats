/**
 * Auth helper: parse JWT from Authorization header or cookie. Returns { userId, isAdmin } or null.
 */
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || process.env.AUTH_SECRET;

function getAuth(req) {
  if (!JWT_SECRET) return null;
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token = authHeader?.replace(/^Bearer\s+/i, '') || req.cookies?.token;
    if (!token) return null;
    const decoded = jwt.verify(token, JWT_SECRET);
    return {
      userId: decoded.sub || decoded.userId || decoded.id,
      isAdmin: decoded.isAdmin === true || decoded.role === 'admin',
    };
  } catch {
    return null;
  }
}

module.exports = { getAuth };
