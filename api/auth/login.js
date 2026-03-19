/**
 * POST /api/auth/login
 * Body: { email, password }
 * Returns: 200 { token, user: { uid, email, displayName, isAdmin, points } } or 401/500 { error }
 */
import { neonAuthSignIn, isNeonAuthConfigured } from '../../api/lib/neonAuth.js';

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  const body = req.body || {};
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!email || !password) {
    json(res, 400, { error: 'Email and password are required' });
    return;
  }

  if (!isNeonAuthConfigured()) {
    json(res, 503, { error: 'Sign in is not configured. Please try again later.' });
    return;
  }

  try {
    const result = await neonAuthSignIn(email, password);
    if (!result || !result.token || !result.user) {
      json(res, 401, { error: 'Sign in failed' });
      return;
    }
    const u = result.user;
    const user = {
      uid: String(u.id),
      email: u.email ?? null,
      displayName: u.display_name ?? null,
      isAdmin: Boolean(u.is_admin),
      points: Number(u.points ?? 0),
    };
    json(res, 200, { token: result.token, user });
  } catch (err) {
    console.error('[auth/login]', err);
    json(res, 500, { error: 'Sign in failed' });
  }
}
