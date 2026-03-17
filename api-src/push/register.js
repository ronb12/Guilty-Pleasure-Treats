/**
 * Register admin device token for new-order push notifications (APNs).
 * POST /api/push/register — body: { deviceToken: string }. Admin only.
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
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session) {
    return res.status(401).json({ error: 'Sign in required' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const deviceToken = req.body?.deviceToken != null ? String(req.body.deviceToken).trim() : '';
  if (!deviceToken) {
    return res.status(400).json({ error: 'deviceToken required' });
  }

  try {
    const isAdmin = Boolean(session.isAdmin);
    await sql`
      INSERT INTO push_tokens (user_id, device_token, is_admin, updated_at)
      VALUES (${session.userId}, ${deviceToken}, ${isAdmin}, NOW())
      ON CONFLICT (user_id) DO UPDATE SET device_token = EXCLUDED.device_token, is_admin = EXCLUDED.is_admin, updated_at = NOW()
    `;
    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('push/register', err);
    if (err?.code === '42P01') {
      return res.status(503).json({ error: 'Push not set up. Run scripts/run-push-tokens-schema.js in Neon.' });
    }
    return res.status(500).json({ error: 'Failed to register device' });
  }
}
