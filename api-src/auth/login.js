import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { verifyPassword, createSession } from '../../api/lib/auth.js';
import { isNeonAuthConfigured, neonAuthSignIn } from '../../api/lib/neonAuth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const emailRaw = body.email ?? body.Email ?? '';
    const email = emailRaw != null ? String(emailRaw).trim() : '';
    const password = body.password != null ? String(body.password) : '';
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    if (isNeonAuthConfigured()) {
      try {
        const result = await neonAuthSignIn(email, password);
        if (result) {
          return res.status(200).json({
            token: result.token,
            user: {
              uid: result.user.id != null ? String(result.user.id) : result.user.id,
              email: result.user.email,
              displayName: result.user.display_name,
              isAdmin: result.user.is_admin,
              points: result.user.points ?? 0,
            },
          });
        }
        // Fallback: try direct DB so admin/local users work even if not in Neon Auth
      } catch (err) {
        console.error('Neon Auth sign-in error', err);
      }
    }

    if (!hasDb() || !sql) {
      return res.status(503).json({
        error: 'Database not configured. Set POSTGRES_URL in Vercel project Environment Variables to your Neon connection string.',
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    let rows;
    try {
      rows = await sql`SELECT id, email, display_name, password_hash, is_admin, points FROM users WHERE email = ${normalizedEmail} LIMIT 1`;
    } catch (err) {
      console.error('login db error', err);
      const code = err?.code || err?.code_;
      if (code === '42P01' || (err?.message && err.message.includes('does not exist'))) {
        return res.status(503).json({ error: 'Database setup incomplete. Run the schema in Neon (users/sessions tables).' });
      }
      return res.status(503).json({ error: 'Database error. Check that POSTGRES_URL is set in Vercel to your Neon connection string.' });
    }

    const user = rows[0];
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    if (!user.password_hash) {
      return res.status(401).json({
        error: 'This account was created with Sign in with Apple. Use the "Sign in with Apple" button to sign in.',
        code: 'USE_APPLE_SIGNIN',
      });
    }

    let valid;
    try {
      const hash = user.password_hash && String(user.password_hash).trim();
      valid = hash && hash.startsWith('$2') ? await verifyPassword(password, hash) : false;
    } catch (err) {
      console.error('login verify password', err);
      return res.status(500).json({ error: 'Sign in failed. Please try again.' });
    }
    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const userId = user.id != null ? String(user.id) : user.id;
    let session;
    try {
      session = await createSession(userId);
    } catch (err) {
      console.error('login createSession', err);
      return res.status(500).json({ error: 'Signed in but session could not be created. Please try again.' });
    }
    if (!session) {
      return res.status(500).json({ error: 'Failed to create session' });
    }

    return res.status(200).json({
      token: String(session.id),
      user: {
        uid: user.id != null ? String(user.id) : user.id,
        email: user.email,
        displayName: user.display_name,
        isAdmin: user.is_admin,
        points: Number(user.points ?? 0),
      },
    });
  } catch (err) {
    console.error('login handler error', err);
    try {
      if (!res.headersSent) res.status(500).json({ error: 'Sign in failed. Please try again.' });
    } catch (resErr) {
      console.error('login send error response', resErr);
    }
  }
}
