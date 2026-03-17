/**
 * GET /api/analytics/summary
 * Admin only. Returns aggregate stats for analytics (e.g. total customer accounts).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  try {
    const rows = await sql`
      SELECT COUNT(*)::int AS count FROM users WHERE is_admin = false
    `;
    const totalCustomers = rows[0]?.count ?? 0;
    return res.status(200).json({ totalCustomers });
  } catch (err) {
    console.error('analytics/summary', err);
    return res.status(500).json({ error: 'Failed to load analytics summary' });
  }
}
