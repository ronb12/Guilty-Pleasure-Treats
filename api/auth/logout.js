/**
 * POST /api/auth/logout — invalidate current local DB session token.
 */
import { deleteSession, getTokenFromRequest } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  if (token) {
    try {
      await deleteSession(token);
    } catch (err) {
      console.error('[auth/logout]', err);
    }
  }

  // Clear cookie if one exists (best-effort; app primarily uses Authorization header token).
  res.setHeader('Set-Cookie', 'session=; Path=/; HttpOnly; Max-Age=0; SameSite=Lax');
  return res.status(200).json({ ok: true });
}
