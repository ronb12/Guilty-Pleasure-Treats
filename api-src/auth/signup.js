import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { hashPassword, createSession } from '../../api/lib/auth.js';
import { isNeonAuthConfigured, neonAuthSignUp } from '../../api/lib/neonAuth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const body = req.body || {};
  const emailRaw = body.email ?? body.Email ?? '';
  const email = emailRaw != null ? String(emailRaw).trim() : '';
  const password = body.password != null ? String(body.password) : '';
  const displayName = body.displayName != null ? String(body.displayName).trim() : null;

  if (!email || !password) {
    const bodyEmpty = Object.keys(body).length === 0;
    return res.status(400).json({
      error: bodyEmpty
        ? 'Email and password required. If you entered them, the server did not receive the request—please try again.'
        : 'Email and password required',
    });
  }

  const normalizedEmail = email.toLowerCase();
  if (!normalizedEmail) {
    return res.status(400).json({ error: 'Please enter a valid email address' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  if (isNeonAuthConfigured()) {
    try {
      const result = await neonAuthSignUp(email, password, displayName);
      if (result && result.success && result.token && result.user) {
        return res.status(201).json({
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
      const statusCode = result?.statusCode || 500;
      const msg = result?.message || '';
      const isDuplicate = statusCode === 409 || /already|exists|duplicate|in use/i.test(msg);
      if (isDuplicate) {
        return res.status(409).json({ error: 'An account with this email already exists. Try signing in instead.' });
      }
      return res.status(statusCode >= 400 && statusCode < 500 ? statusCode : 500).json({
        error: msg && msg.length < 200 ? msg : 'Sign-up failed. Please try again.',
      });
    } catch (err) {
      console.error('Neon Auth sign-up error', err);
      return res.status(500).json({ error: 'Sign-up failed. Please try again.' });
    }
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({
      error: 'Database not configured. Set POSTGRES_URL in Vercel project Environment Variables to your Neon connection string.',
    });
  }

  let existing;
  try {
    existing = await sql`SELECT id FROM users WHERE LOWER(TRIM(email)) = ${normalizedEmail} LIMIT 1`;
  } catch (err) {
    console.error('signup check existing', err);
    return res.status(500).json({ error: 'Unable to create account. Please try again.' });
  }
  if (existing.length) {
    let usedApple = false;
    try {
      const withApple = await sql`SELECT 1 FROM users WHERE LOWER(TRIM(email)) = ${normalizedEmail} AND apple_id IS NOT NULL AND TRIM(apple_id) != '' LIMIT 1`;
      usedApple = withApple.length > 0;
    } catch (_) { /* apple_id column may not exist in older DBs */ }
    const message = usedApple
      ? 'This email is already used with Sign in with Apple. Please sign in with Apple instead.'
      : 'An account with this email already exists. Try signing in with your password.';
    return res.status(409).json({ error: message });
  }

  let passwordHash;
  try {
    passwordHash = await hashPassword(password);
  } catch (err) {
    console.error('signup hash', err);
    return res.status(500).json({ error: 'Unable to create account. Please try again.' });
  }

  let rows;
  try {
    rows = await sql`
      INSERT INTO users (email, display_name, password_hash, is_admin, points)
      VALUES (${normalizedEmail}, ${displayName || null}, ${passwordHash}, false, 0)
      RETURNING id, email, display_name, is_admin, points
    `;
  } catch (err) {
    console.error('signup insert user', err);
    if (err.code === '42P01') {
      return res.status(503).json({ error: 'Database setup incomplete. Please contact support.' });
    }
    return res.status(500).json({ error: 'Unable to create account. Please try again.' });
  }

  const user = rows[0];
  if (!user) {
    return res.status(500).json({ error: 'Failed to create account' });
  }

  let session;
  try {
    session = await createSession(user.id);
  } catch (err) {
    console.error('signup createSession', err);
    return res.status(500).json({ error: 'Account created but could not sign you in. Please sign in with your email and password.' });
  }
  if (!session) {
    return res.status(500).json({ error: 'Account created but could not sign you in. Please sign in with your email and password.' });
  }

  res.status(201).json({
    token: String(session.id),
    user: {
      uid: user.id != null ? String(user.id) : user.id,
      email: user.email ?? normalizedEmail,
      displayName: user.display_name ?? null,
      isAdmin: Boolean(user.is_admin),
      points: Number(user.points ?? 0),
    },
  });
}
