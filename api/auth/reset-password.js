/**
 * POST /api/auth/reset-password
 * Body: { token, newPassword }
 * Sets a new password for the user tied to the token; updates public.users.password_hash and
 * neon_auth.account (credential) when present so Neon Auth sign-in stays in sync.
 */
import { createHash } from 'crypto';
import { hashPassword } from '../../api/lib/auth.js';
import { sql, hasDb } from '../../api/lib/db.js';
import { isNeonAuthConfigured } from '../../api/lib/neonAuth.js';
import { checkRateLimit } from '../lib/rateLimit.js';

const MIN_PASSWORD_LEN = 6;

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

function hashToken(plain) {
  return createHash('sha256').update(plain, 'utf8').digest('hex');
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  if (!checkRateLimit(req, 'auth_reset_password', { max: 12, windowMs: 900_000 })) {
    json(res, 429, { error: 'Too many attempts. Please try again later.' });
    return;
  }

  if (!isNeonAuthConfigured()) {
    json(res, 503, { error: 'Password reset is not configured. Please try again later.' });
    return;
  }
  if (!hasDb() || !sql) {
    json(res, 503, { error: 'Database is not available.' });
    return;
  }

  const body = req.body || {};
  const token = typeof body.token === 'string' ? body.token.trim() : '';
  const newPassword = typeof body.newPassword === 'string' ? body.newPassword : '';
  if (!token) {
    json(res, 400, { error: 'Token is required' });
    return;
  }
  if (!newPassword || newPassword.length < MIN_PASSWORD_LEN) {
    json(res, 400, { error: `Password must be at least ${MIN_PASSWORD_LEN} characters` });
    return;
  }

  try {
    const tokenHash = hashToken(token);
    let rows;
    try {
      rows = await sql`
        SELECT user_id, expires_at
        FROM password_reset_tokens
        WHERE token = ${tokenHash} AND expires_at > NOW()
        LIMIT 1
      `;
    } catch (selErr) {
      if (selErr?.code === '42703' && /column.*token/i.test(String(selErr.message || ''))) {
        rows = await sql`
          SELECT user_id, expires_at
          FROM password_reset_tokens
          WHERE token_hash = ${tokenHash} AND expires_at > NOW()
          LIMIT 1
        `;
      } else {
        throw selErr;
      }
    }

    const match = rows[0];
    if (!match) {
      json(res, 400, { error: 'Invalid or expired reset link. Request a new one from Forgot password.' });
      return;
    }

    const userId = match.user_id;
    const userRows = await sql`
      SELECT id, neon_auth_id FROM users WHERE id = ${userId} LIMIT 1
    `;
    const user = userRows[0];
    if (!user) {
      await sql`DELETE FROM password_reset_tokens WHERE token = ${tokenHash}`;
      json(res, 400, { error: 'Invalid or expired reset link.' });
      return;
    }

    const bcryptHash = await hashPassword(newPassword);
    const neonUserId = user.neon_auth_id || user.id;

    await sql`
      UPDATE users SET password_hash = ${bcryptHash}, updated_at = NOW() WHERE id = ${userId}
    `;

    try {
      await sql`
        UPDATE neon_auth.account
        SET password = ${bcryptHash}, "updatedAt" = NOW()
        WHERE "userId" = ${neonUserId} AND "providerId" = 'credential'
      `;
    } catch (e) {
      if (e?.code === '42P01' || /neon_auth/i.test(String(e?.message || ''))) {
        console.warn('[auth/reset-password] neon_auth.account update skipped', e?.message);
      } else {
        throw e;
      }
    }

    await sql`DELETE FROM password_reset_tokens WHERE user_id = ${userId}`;
    json(res, 200, { ok: true });
  } catch (err) {
    if (err?.code === '42P01' || /password_reset_tokens/i.test(String(err?.message || ''))) {
      console.error('[auth/reset-password] missing table password_reset_tokens', err);
      json(res, 503, { error: 'Password reset is not ready. Please contact support.' });
      return;
    }
    console.error('[auth/reset-password]', err);
    json(res, 500, { error: 'Could not reset password' });
  }
}
