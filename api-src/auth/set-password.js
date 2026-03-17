/**
 * One-time set password for an existing user. Protected by SET_PASSWORD_SECRET.
 * POST body: { email, newPassword, secret }
 * Set SET_PASSWORD_SECRET in Vercel env, call once, then remove the env var for security.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { hashPassword, verifyPassword } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const secret = process.env.SET_PASSWORD_SECRET;
  if (!secret || typeof secret !== 'string' || !secret.trim()) {
    return res.status(503).json({
      error: 'Set password is not configured. Set SET_PASSWORD_SECRET in Vercel Environment Variables to use this endpoint.',
    });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const email = body.email != null ? String(body.email).trim() : '';
  const newPassword = body.newPassword != null ? String(body.newPassword).trim() : '';
  const providedSecret = body.secret != null ? String(body.secret) : '';

  if (!email || !newPassword || providedSecret !== secret.trim()) {
    return res.status(400).json({ error: 'Email, newPassword, and valid secret required' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const normalizedEmail = email.toLowerCase();
  let rows;
  try {
    rows = await sql`SELECT id FROM users WHERE email = ${normalizedEmail} LIMIT 1`;
  } catch (err) {
    console.error('set-password lookup', err);
    return res.status(500).json({ error: 'Database error' });
  }
  if (!rows.length) {
    return res.status(404).json({ error: 'No account found with this email' });
  }

  let passwordHash;
  try {
    passwordHash = await hashPassword(newPassword);
  } catch (err) {
    console.error('set-password hash', err);
    return res.status(500).json({ error: 'Failed to set password' });
  }

  let updated;
  try {
    updated = await sql`
      UPDATE users SET password_hash = ${passwordHash}
      WHERE email = ${normalizedEmail}
    `;
  } catch (err) {
    console.error('set-password update', err);
    return res.status(500).json({ error: 'Failed to update password' });
  }

  // Verify the stored hash works (catches DB replication lag or storage issues)
  const verifyRows = await sql`SELECT password_hash FROM users WHERE email = ${normalizedEmail} LIMIT 1`;
  const storedHash = verifyRows[0]?.password_hash;
  if (!storedHash) {
    return res.status(500).json({ error: 'Password was not saved correctly. Please try again.' });
  }
  const matches = await verifyPassword(newPassword, storedHash);
  if (!matches) {
    console.error('set-password: stored hash did not verify');
    return res.status(500).json({ error: 'Password save verification failed. Please try again.' });
  }

  res.status(200).json({ ok: true, message: 'Password updated. You can now sign in with your email and new password.' });
}
