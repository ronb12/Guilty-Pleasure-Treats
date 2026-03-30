/**
 * POST /api/auth/login
 * Body: { email, password }
 * Returns: 200 { token, user: { uid, email, displayName, isAdmin, points } } or 401/500 { error }
 *
 * Sign-in order (avoids 401 when Neon credential is out of sync with public.users):
 *   1) public.users.password_hash (bcrypt — set-user-password / reset flow)
 *   2) Neon Auth (email/password in neon_auth.account)
 *   3) ADMIN_FALLBACK_EMAIL + ADMIN_FALLBACK_PASSWORD (Vercel env)
 *
 * Vercel must set DATABASE_URL (or POSTGRES_URL) for the bcrypt path; without it, only Neon Auth runs.
 */
import { neonAuthSignIn, isNeonAuthConfigured } from '../../api/lib/neonAuth.js';
import {
  createSession,
  verifyPassword,
  sessionHasAdminAccess,
  coerceAdminFlag,
  issueApiSessionTokenIfJwt,
} from '../../api/lib/auth.js';
import { sql, hasDb, awaitNeonRows } from '../../api/lib/db.js';

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

/** Password matched bcrypt but sessions insert failed — do not return 401 (misleading). */
const LOGIN_DB_SESSION_FAILED = { __loginDbSessionFailed: true };

/** @returns {Promise<{ token: string, user: object } | null | typeof LOGIN_DB_SESSION_FAILED>} */
async function loginWithDbPasswordHash(email, password) {
  if (!hasDb() || !sql) return null;
  let rows;
  try {
    rows = await sql`
      SELECT id, email, display_name, phone, is_admin, points, password_hash
      FROM users
      WHERE LOWER(TRIM(COALESCE(email, ''))) = ${email.toLowerCase()}
      LIMIT 1
    `;
  } catch (e) {
    console.error('[auth/login] db user lookup failed', e?.message ?? e);
    return null;
  }
  const userRow = Array.isArray(rows) ? rows[0] : rows;
  if (!userRow) return null;
  const hash = userRow.password_hash != null ? String(userRow.password_hash).trim() : '';
  if (hash.length < 10) return null;
  if (!(await verifyPassword(password, hash))) return null;
  const session = await createSession(userRow.id);
  if (!session) {
    console.error('[auth/login] createSession failed after valid bcrypt for', email.toLowerCase());
    return LOGIN_DB_SESSION_FAILED;
  }
  return {
    token: session.id,
    user: {
      id: userRow.id,
      email: userRow.email,
      display_name: userRow.display_name,
      phone: userRow.phone ?? null,
      is_admin: coerceAdminFlag(userRow.is_admin),
      points: Number(userRow.points ?? 0),
    },
  };
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  const body = req.body || {};
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password.trim() : '';

  if (!email || !password) {
    json(res, 400, { error: 'Email and password are required' });
    return;
  }

  if (!isNeonAuthConfigured()) {
    json(res, 503, { error: 'Sign in is not configured. Please try again later.' });
    return;
  }

  try {
    let result = await loginWithDbPasswordHash(email, password);

    if (result && result.__loginDbSessionFailed) {
      json(res, 503, {
        error:
          'Your password was accepted but the server could not create a session. Check Vercel DATABASE_URL and the sessions table, then try again.',
        code: 'session_create_failed',
      });
      return;
    }

    if (!result || !result.token || !result.user) {
      result = await neonAuthSignIn(email, password);
    }

    // Optional: admin fallback when Neon Auth rejects and no public.users password match
    if ((!result || !result.token || !result.user) && hasDb() && sql) {
      const fallbackEmail = (process.env.ADMIN_FALLBACK_EMAIL || '').trim().toLowerCase();
      const fallbackPassword = (process.env.ADMIN_FALLBACK_PASSWORD || '').trim();
      if (fallbackEmail && fallbackPassword && email.toLowerCase() === fallbackEmail && password === fallbackPassword) {
        let rows = await awaitNeonRows(
          sql`SELECT id, email, display_name, phone, is_admin, points FROM users WHERE LOWER(TRIM(COALESCE(email, ''))) = ${fallbackEmail} LIMIT 1`,
          'login_admin_fallback_lookup'
        );
        let userRow = rows[0];
        if (!userRow) {
          const insertRows = await awaitNeonRows(
            sql`
            INSERT INTO users (email, display_name, is_admin, points)
            VALUES (${email}, 'Admin', true, 0)
            RETURNING id, email, display_name, is_admin, points
          `,
            'login_admin_fallback_insert'
          );
          userRow = insertRows[0];
        }
        if (userRow) {
          const session = await createSession(userRow.id);
          if (session) {
            result = {
              token: session.id,
              user: {
                id: userRow.id,
                email: userRow.email,
                display_name: userRow.display_name,
                phone: userRow.phone ?? null,
                is_admin: coerceAdminFlag(userRow.is_admin),
                points: Number(userRow.points ?? 0),
              },
            };
          }
        }
      }
    }

    if (!result || !result.token || !result.user) {
      json(res, 401, { error: 'Invalid email or password.', code: 'invalid_credentials' });
      return;
    }
    const u = result.user;
    const sessionLike = {
      userId: String(u.id),
      email: u.email ?? null,
      isAdmin: coerceAdminFlag(u.is_admin),
    };
    const user = {
      uid: String(u.id),
      email: u.email ?? null,
      displayName: u.display_name ?? null,
      phone: u.phone ?? null,
      isAdmin: sessionHasAdminAccess(sessionLike),
      points: Number(u.points ?? 0),
    };
    const apiToken = await issueApiSessionTokenIfJwt(u.id, result.token);
    json(res, 200, { token: apiToken, user });
  } catch (err) {
    console.error('[auth/login]', err);
    json(res, 500, { error: 'Sign in failed' });
  }
}
