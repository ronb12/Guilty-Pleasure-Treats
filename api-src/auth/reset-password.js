/**
 * POST /api/auth/reset-password
 * Body: { token, newPassword }
 * Validates token, updates user password, deletes token.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { hashPassword } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const token = body.token != null ? String(body.token).trim() : '';
  const newPassword = body.newPassword != null ? String(body.newPassword).trim() : '';

  if (!token || !newPassword) {
    return res.status(400).json({ error: 'Token and new password required' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  try {
    const rows = await sql`
      SELECT prt.user_id FROM password_reset_tokens prt
      WHERE prt.token = ${token} AND prt.expires_at > NOW()
      LIMIT 1
    `;
    const row = rows[0];
    if (!row) {
      return res.status(400).json({ error: 'This link has expired or is invalid. Please request a new password reset.' });
    }

    const passwordHash = await hashPassword(newPassword);
    await sql`UPDATE users SET password_hash = ${passwordHash}, updated_at = NOW() WHERE id = ${row.user_id}`;
    await sql`DELETE FROM password_reset_tokens WHERE token = ${token}`;

    return res.status(200).json({ message: 'Password updated. You can now sign in with your new password.' });
  } catch (err) {
    console.error('reset-password', err);
    return res.status(500).json({ error: 'Something went wrong. Please try again.' });
  }
}
