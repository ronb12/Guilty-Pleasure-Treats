/**
 * POST /api/auth/forgot-password
 * Body: { email }
 * Creates a one-time reset token and returns it (in-app flow; no email required).
 * Token valid 1 hour. Use with POST /api/auth/reset-password.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { randomBytes } from 'crypto';

const TOKEN_BYTES = 32;
const EXPIRY_HOURS = 1;

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
  const emailRaw = body.email ?? '';
  const email = String(emailRaw).trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ error: 'Email required' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  try {
    const rows = await sql`
      SELECT id, password_hash FROM users
      WHERE LOWER(TRIM(email)) = ${email} LIMIT 1
    `;
    const user = rows[0];
    if (!user) {
      return res.status(200).json({ message: 'If an account exists with this email, you can set a new password in the next step.' });
    }
    if (!user.password_hash || String(user.password_hash).trim() === '') {
      return res.status(400).json({
        error: 'This account uses Sign in with Apple. Use the "Sign in with Apple" button instead.',
        code: 'USE_APPLE_SIGNIN',
      });
    }

    const token = randomBytes(TOKEN_BYTES).toString('hex');
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + EXPIRY_HOURS);

    await sql`DELETE FROM password_reset_tokens WHERE user_id = ${user.id}`;
    await sql`
      INSERT INTO password_reset_tokens (token, user_id, expires_at)
      VALUES (${token}, ${user.id}, ${expiresAt})
    `;

    return res.status(200).json({ token, expiresAt: expiresAt.toISOString() });
  } catch (err) {
    console.error('forgot-password', err);
    return res.status(500).json({ error: 'Something went wrong. Please try again.' });
  }
}
