/**
 * POST /api/auth/login
 * Body: { email, password }
 * Returns: 200 { token, user: { uid, email, displayName, isAdmin, points } } or 401/500 { error }
 *
 * Uses Neon Auth when NEON_AUTH_URL is set. Optional fallback: set ADMIN_FALLBACK_EMAIL and
 * ADMIN_FALLBACK_PASSWORD in Vercel env; if Neon sign-in fails and credentials match, sign in
 * with a DB session (so you can log in as admin without Neon Auth).
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

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  const body = req.body || {};
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!email || !password) {
    json(res, 400, { error: 'Email and password are required' });
    return;
  }

  if (!isNeonAuthConfigured()) {
    json(res, 503, { error: 'Sign in is not configured. Please try again later.' });
    return;
  }

  try {
    let result = null;

    // Prefer public.users password_hash when present (admin / legacy) so login works even if
    // Neon Auth rejects (wrong Neon password, Auth domain issues) or prod DB differs from Neon Auth store.
    if (hasDb() && sql) {
      const dbUsers = await awaitNeonRows(
        sql`
        SELECT id, email, display_name, phone, is_admin, points, password_hash
        FROM users
        WHERE LOWER(email) = ${email.toLowerCase()}
        LIMIT 1
      `,
        'login_db_user_lookup'
      );
      const userRow = dbUsers[0];
      const hash = userRow?.password_hash != null ? String(userRow.password_hash).trim() : '';
      if (userRow && hash.length >= 10 && (await verifyPassword(password, hash))) {
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

    if (!result || !result.token || !result.user) {
      result = await neonAuthSignIn(email, password);
    }

    // Optional: admin fallback when Neon Auth rejects and no public.users password match
    if ((!result || !result.token || !result.user) && hasDb() && sql) {
      const fallbackEmail = (process.env.ADMIN_FALLBACK_EMAIL || '').trim().toLowerCase();
      const fallbackPassword = process.env.ADMIN_FALLBACK_PASSWORD || '';
      if (fallbackEmail && fallbackPassword && email.toLowerCase() === fallbackEmail && password === fallbackPassword) {
        let rows = await awaitNeonRows(
          sql`SELECT id, email, display_name, phone, is_admin, points FROM users WHERE LOWER(email) = ${fallbackEmail} LIMIT 1`,
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
      json(res, 401, { error: 'Invalid email or password.' });
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
