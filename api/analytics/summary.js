/**
 * GET /api/analytics/summary — admin only. Returns { totalCustomers } (non-admin users).
 */
import { sql, hasDb } from '../../api/lib/db.js';
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
  if (!session?.userId || session.isAdmin !== true) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  try {
    const rows = await sql`
      SELECT COUNT(*)::int AS c FROM users WHERE COALESCE(is_admin, false) = false
    `;
    const total = rows[0]?.c ?? 0;
    return res.status(200).json({ totalCustomers: total });
  } catch (err) {
    console.error('[analytics/summary]', err);
    return res.status(500).json({ error: 'Failed to load summary' });
  }
}
