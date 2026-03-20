/**
 * POST /api/auth/forgot-password
 * Body: { email }
 * Returns: 200 { token?: string } — token present only when a password reset is allowed (email/password account).
 * Apple-only or unknown email returns 200 with no token (no enumeration).
 *
 * Env: NEON_AUTH_URL (same as login). Requires DB + password_reset_tokens table (see scripts/run-missing-tables.js).
 */
import { createHash, randomBytes } from 'crypto';
import { sql, hasDb } from '../../api/lib/db.js';
import { isNeonAuthConfigured } from '../../api/lib/neonAuth.js';
import { checkRateLimit } from '../lib/rateLimit.js';

const RESET_TOKEN_BYTES = 32;
const RESET_EXPIRY_MS = 60 * 60 * 1000; // 1 hour (matches app comment)

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

function hashToken(plain) {
  return createHash('sha256').update(plain, 'utf8').digest('hex');
}

/**
 * User can reset if they have a credential (email/password) in Neon Auth or a bcrypt password in public.users.
 */
async function findResettableUser(emailNorm) {
  // Only columns we need — avoid optional columns (e.g. apple_sub) that older DBs may lack.
  const rows = await sql`
    SELECT id, neon_auth_id, password_hash
    FROM users
    WHERE LOWER(TRIM(email)) = ${emailNorm}
    LIMIT 1
  `;
  const u = rows[0];
  if (!u) return null;

  const neonUserId = u.neon_auth_id || u.id;
  let hasCredential = false;
  try {
    const cred = await sql`
      SELECT 1 FROM neon_auth.account
      WHERE "userId" = ${neonUserId} AND "providerId" = 'credential'
      LIMIT 1
    `;
    hasCredential = cred.length > 0;
  } catch (e) {
    if (e?.code === '42P01' || /neon_auth/i.test(String(e?.message || ''))) {
      hasCredential = false;
    } else {
      throw e;
    }
  }

  const hasLocalPassword = u.password_hash != null && String(u.password_hash).length > 0;
  if (hasCredential || hasLocalPassword) {
    return { userId: u.id, neonUserId };
  }
  return null;
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  if (!checkRateLimit(req, 'auth_forgot_password', { max: 8, windowMs: 900_000 })) {
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
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (!email) {
    json(res, 400, { error: 'Email is required' });
    return;
  }

  try {
    const user = await findResettableUser(email);
    if (!user) {
      json(res, 200, {});
      return;
    }

    const plainToken = randomBytes(RESET_TOKEN_BYTES).toString('hex');
    const tokenHash = hashToken(plainToken);
    const expiresAt = new Date(Date.now() + RESET_EXPIRY_MS);

    await sql`DELETE FROM password_reset_tokens WHERE user_id = ${user.userId}`;
    await sql`
      INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
      VALUES (${user.userId}, ${tokenHash}, ${expiresAt})
    `;

    json(res, 200, { token: plainToken });
  } catch (err) {
    if (err?.code === '42P01' || /password_reset_tokens/i.test(String(err?.message || ''))) {
      console.error('[auth/forgot-password] missing table password_reset_tokens — run scripts/run-missing-tables.js', err);
      json(res, 503, { error: 'Password reset is not ready. Please contact support.' });
      return;
    }
    console.error('[auth/forgot-password]', err);
    json(res, 500, { error: 'Could not process request' });
  }
}
