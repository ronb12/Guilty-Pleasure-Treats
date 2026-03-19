/**
 * CORS helper for Vercel serverless. Wraps handler and sets CORS headers.
 */
const DEFAULT_ORIGIN = '*';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', DEFAULT_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
}

function handleOptions(res) {
  setCors(res);
  res.status(204).end();
}

function withCors(req, res, next) {
  const origin = req.headers.origin || req.headers.referer || DEFAULT_ORIGIN;
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (typeof next === 'function') return next();
  return undefined;
}

module.exports = { setCors, handleOptions, withCors };
