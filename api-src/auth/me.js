/**
 * GET /api/auth/me — validate session; returns same shape as login user payload.
 */
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  return res.status(200).json({
    uid: String(session.userId),
    email: session.email ?? null,
    displayName: session.displayName ?? null,
    phone: session.phone ?? null,
    isAdmin: Boolean(session.isAdmin),
    points: Number(session.points ?? 0),
  });
}
