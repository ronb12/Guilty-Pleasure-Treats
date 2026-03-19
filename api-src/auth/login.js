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
import { createSession, verifyPassword } from '../../api/lib/auth.js';
import { sql, hasDb } from '../../api/lib/db.js';

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
    let result = await neonAuthSignIn(email, password);

    // If Neon Auth fails, try public.users (password_hash) so dashboard-set passwords work
    if ((!result || !result.token || !result.user) && hasDb() && sql) {
      const dbUsers = await sql`
        SELECT id, email, display_name, phone, is_admin, points, password_hash
        FROM users
        WHERE LOWER(email) = ${email.toLowerCase()} AND password_hash IS NOT NULL
        LIMIT 1
      `;
      const userRow = dbUsers[0];
      if (userRow && await verifyPassword(password, userRow.password_hash)) {
        const session = await createSession(userRow.id);
        if (session) {
          result = {
            token: session.id,
            user: {
              id: userRow.id,
              email: userRow.email,
              display_name: userRow.display_name,
              phone: userRow.phone ?? null,
              is_admin: Boolean(userRow.is_admin),
              points: Number(userRow.points ?? 0),
            },
          };
        }
      }
    }

    // Optional: admin fallback when Neon Auth rejects and no public.users password match
    if ((!result || !result.token || !result.user) && hasDb() && sql) {
      const fallbackEmail = (process.env.ADMIN_FALLBACK_EMAIL || '').trim().toLowerCase();
      const fallbackPassword = process.env.ADMIN_FALLBACK_PASSWORD || '';
      if (fallbackEmail && fallbackPassword && email.toLowerCase() === fallbackEmail && password === fallbackPassword) {
        let rows = await sql`SELECT id, email, display_name, phone, is_admin, points FROM users WHERE LOWER(email) = ${fallbackEmail} LIMIT 1`;
        let userRow = rows[0];
        if (!userRow) {
          const insertRows = await sql`
            INSERT INTO users (email, display_name, is_admin, points)
            VALUES (${email}, 'Admin', true, 0)
            RETURNING id, email, display_name, is_admin, points
          `;
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
                is_admin: Boolean(userRow.is_admin),
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
    const user = {
      uid: String(u.id),
      email: u.email ?? null,
      displayName: u.display_name ?? null,
      phone: u.phone ?? null,
      isAdmin: Boolean(u.is_admin),
      points: Number(u.points ?? 0),
    };
    json(res, 200, { token: result.token, user });
  } catch (err) {
    console.error('[auth/login]', err);
    json(res, 500, { error: 'Sign in failed' });
  }
}
