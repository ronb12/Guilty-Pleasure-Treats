export function setCors(res) {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

export function handleOptions(res) {
  setCors(res);
  res.status(204).end();
}

/** For handlers that pass (req, res, next): sets CORS and handles OPTIONS. */
export function withCors(req, res, next) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (typeof next === 'function') next();
}
