/**
 * POST /api/auth/signup
 * Body: { email, password, displayName?, phone } — phone required for app checkout prefill.
 * Returns: 200 { token, user: { uid, email, displayName, phone, isAdmin, points } } or 4xx/5xx { error }
 */
import { neonAuthSignUp, isNeonAuthConfigured } from '../../api/lib/neonAuth.js';
import { sql, hasDb } from '../../api/lib/db.js';
import { issueApiSessionTokenIfJwt } from '../../api/lib/auth.js';
import { checkRateLimit } from '../lib/rateLimit.js';

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  if (!checkRateLimit(req, 'auth_signup', { max: 12, windowMs: 900_000 })) {
    json(res, 429, { error: 'Too many sign-up attempts from this network. Please try again later.' });
    return;
  }

  const body = req.body || {};
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const displayName = typeof body.displayName === 'string' ? body.displayName.trim() : '';
  const phone = typeof body.phone === 'string' ? body.phone.trim() : '';
  const foodAllergiesRaw = body.foodAllergies != null ? String(body.foodAllergies).trim() : '';
  const foodAllergies = foodAllergiesRaw ? foodAllergiesRaw.slice(0, 2000) : null;

  if (!email || !password) {
    json(res, 400, { error: 'Email and password are required' });
    return;
  }
  if (!phone) {
    json(res, 400, { error: 'Phone number is required' });
    return;
  }

  if (!isNeonAuthConfigured()) {
    json(res, 503, { error: 'Sign up is not configured. Please try again later.' });
    return;
  }

  try {
    const nameForNeon = displayName || undefined;
    const result = await neonAuthSignUp(email, password, nameForNeon);

    if (!result.success || !result.token || !result.user) {
      const status = result.statusCode && result.statusCode >= 400 && result.statusCode < 600 ? result.statusCode : 400;
      const msg = result.message || 'Sign up failed';
      const duplicate = status === 409 || /already|exists|duplicate|in use/i.test(msg);
      json(res, duplicate ? 409 : status, { error: msg });
      return;
    }

    const userId = result.user.id;
    if (hasDb() && sql && userId) {
      try {
        try {
          await sql`ALTER TABLE users ADD COLUMN IF NOT EXISTS food_allergies TEXT`;
        } catch (_) { /* ignore */ }
        if (foodAllergies != null) {
          await sql`
            UPDATE users SET phone = ${phone}, food_allergies = ${foodAllergies}, updated_at = NOW()
            WHERE id = ${userId}
          `;
        } else {
          await sql`
            UPDATE users SET phone = ${phone}, updated_at = NOW()
            WHERE id = ${userId}
          `;
        }
      } catch (e) {
        console.error('[auth/signup] phone/allergies update', e);
      }
    }

    let u = result.user;
    if (hasDb() && sql && userId) {
      try {
        const rows = await sql`
          SELECT id, email, display_name, phone, food_allergies, is_admin, points
          FROM users WHERE id = ${userId} LIMIT 1
        `;
        if (rows[0]) u = { ...u, ...rows[0] };
      } catch (_) { /* ignore */ }
    }

    const apiToken = await issueApiSessionTokenIfJwt(userId, result.token);
    json(res, 200, {
      token: apiToken,
      user: {
        uid: String(u.id),
        email: u.email ?? null,
        displayName: u.display_name ?? null,
        phone: u.phone ?? phone,
        foodAllergies: u.food_allergies != null && String(u.food_allergies).trim() !== '' ? String(u.food_allergies).trim() : null,
        isAdmin: Boolean(u.is_admin),
        points: Number(u.points ?? 0),
      },
    });
  } catch (err) {
    console.error('[auth/signup]', err);
    json(res, 500, { error: 'Sign up failed' });
  }
}
