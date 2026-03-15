import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session) {
    return res.status(401).json({ error: 'Not signed in' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    const rows = await sql`SELECT id, email, display_name, is_admin, points, created_at FROM users WHERE id = ${session.userId} LIMIT 1`;
    const u = rows[0];
    if (!u) return res.status(404).json({ error: 'User not found' });
    return res.status(200).json({
      uid: u.id != null ? String(u.id) : u.id,
      email: u.email,
      displayName: u.display_name,
      isAdmin: u.is_admin,
      points: Number(u.points ?? 0),
      createdAt: u.created_at ? new Date(u.created_at).toISOString() : null,
    });
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    if (body.displayName !== undefined) {
      await sql`UPDATE users SET display_name = ${String(body.displayName).trim()}, updated_at = NOW() WHERE id = ${session.userId}`;
    }
    if (typeof body.addPoints === 'number' && body.addPoints > 0) {
      await sql`UPDATE users SET points = points + ${body.addPoints}, updated_at = NOW() WHERE id = ${session.userId}`;
    }
    if (typeof body.redeemPoints === 'number' && body.redeemPoints > 0) {
      const rows = await sql`SELECT points FROM users WHERE id = ${session.userId} LIMIT 1`;
      const current = Number(rows[0]?.points ?? 0);
      if (current >= body.redeemPoints) {
        await sql`UPDATE users SET points = points - ${body.redeemPoints}, updated_at = NOW() WHERE id = ${session.userId}`;
      }
    }
    const rows = await sql`SELECT id, email, display_name, is_admin, points FROM users WHERE id = ${session.userId} LIMIT 1`;
    const u = rows[0];
    return res.status(200).json({
      uid: u.id != null ? String(u.id) : u.id,
      email: u.email,
      displayName: u.display_name,
      isAdmin: u.is_admin,
      points: Number(u.points ?? 0),
    });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
