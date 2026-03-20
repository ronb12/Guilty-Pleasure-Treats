/**
 * POST /api/auth/apple
 * Body: { identityToken, rawNonce, fullName?: { givenName, familyName } }
 * Verifies Apple identity token, upserts user by apple_sub, returns session like /auth/login.
 *
 * Env: APPLE_BUNDLE_ID and/or APPLE_CLIENT_ID — must include every native bundle ID that
 * appears as the JWT `aud` claim (iOS + Mac targets if they differ). Comma-separated OK.
 */
import { createHash } from 'crypto';
import * as jose from 'jose';
import { createSession } from '../../api/lib/auth.js';
import { sql, hasDb } from '../../api/lib/db.js';
import { checkRateLimit } from '../lib/rateLimit.js';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_JWKS = jose.createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

function json(res, status, data) {
  res.setHeader('Content-Type', 'application/json');
  res.status(status).json(data);
}

function audienceList() {
  const raw = [process.env.APPLE_BUNDLE_ID, process.env.APPLE_CLIENT_ID]
    .filter(Boolean)
    .join(',');
  const parts = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return [...new Set(parts)];
}

function sha256Hex(utf8) {
  return createHash('sha256').update(utf8, 'utf8').digest('hex');
}

function displayNameFromBody(body) {
  const fn = body.fullName;
  if (!fn || typeof fn !== 'object') return null;
  const g = typeof fn.givenName === 'string' ? fn.givenName.trim() : '';
  const f = typeof fn.familyName === 'string' ? fn.familyName.trim() : '';
  const combined = `${g} ${f}`.trim();
  return combined.length ? combined : null;
}

export default async function handler(req, res) {
  if ((req.method || '').toUpperCase() !== 'POST') {
    json(res, 405, { error: 'Method not allowed' });
    return;
  }

  if (!checkRateLimit(req, 'auth_apple', { max: 30, windowMs: 900_000 })) {
    json(res, 429, { error: 'Too many sign-in attempts. Please try again later.' });
    return;
  }

  const audiences = audienceList();
  if (!audiences.length) {
    json(res, 503, { error: 'Sign in with Apple is not configured on the server.' });
    return;
  }
  if (!hasDb() || !sql) {
    json(res, 503, { error: 'Database is not available.' });
    return;
  }

  const body = req.body || {};
  const identityToken = typeof body.identityToken === 'string' ? body.identityToken.trim() : '';
  const rawNonce =
    typeof body.rawNonce === 'string' ? body.rawNonce.trim() : typeof body.rawNonce === 'number' ? String(body.rawNonce) : '';
  if (!identityToken || !rawNonce) {
    json(res, 400, { error: 'Invalid Sign in with Apple request.' });
    return;
  }

  let payload;
  try {
    const verifyOpts = {
      issuer: APPLE_ISSUER,
      audience: audiences.length === 1 ? audiences[0] : audiences,
      /** Device clock skew can cause “jwt expired” / “nbf” failures without this. */
      clockTolerance: '120s',
    };
    const verified = await jose.jwtVerify(identityToken, APPLE_JWKS, verifyOpts);
    payload = verified.payload;
  } catch (err) {
    let tokenAud = null;
    try {
      const decoded = jose.decodeJwt(identityToken);
      tokenAud = decoded?.aud ?? null;
    } catch (_) { /* ignore decode errors */ }
    console.error('[auth/apple] jwtVerify failed', {
      message: err?.message || String(err),
      code: err?.code,
      tokenAud,
      allowedAudiences: audiences,
    });
    json(res, 401, { error: 'Sign in with Apple could not be verified. Please try again.' });
    return;
  }

  const expectedNonce = sha256Hex(rawNonce);
  const tokenNonce = payload.nonce != null ? String(payload.nonce).trim() : '';
  if (
    !tokenNonce ||
    tokenNonce.toLowerCase() !== expectedNonce.toLowerCase()
  ) {
    console.error('[auth/apple] nonce mismatch', {
      expectedLen: expectedNonce.length,
      tokenLen: tokenNonce.length,
    });
    json(res, 401, { error: 'Sign in with Apple could not be verified. Please try again.' });
    return;
  }

  const sub = typeof payload.sub === 'string' ? payload.sub : '';
  if (!sub) {
    json(res, 401, { error: 'Invalid Apple account.' });
    return;
  }

  const tokenEmail = typeof payload.email === 'string' ? payload.email.trim() : null;
  const fromClientName = displayNameFromBody(body);

  try {
    let rows = await sql`
      SELECT id, email, display_name, phone, is_admin, points, apple_sub
      FROM users
      WHERE apple_sub = ${sub}
      LIMIT 1
    `;
    let userRow = rows[0];

    if (!userRow) {
      const email = tokenEmail || null;
      const displayName = fromClientName || null;
      const inserted = await sql`
        INSERT INTO users (email, display_name, apple_sub, points, is_admin)
        VALUES (${email}, ${displayName}, ${sub}, 0, false)
        RETURNING id, email, display_name, phone, is_admin, points
      `;
      userRow = inserted[0];
    } else {
      if (!userRow.email && tokenEmail) {
        await sql`
          UPDATE users SET email = ${tokenEmail}, updated_at = NOW()
          WHERE id = ${userRow.id}
        `;
        userRow = { ...userRow, email: tokenEmail };
      }
      if ((!userRow.display_name || !String(userRow.display_name).trim()) && fromClientName) {
        await sql`
          UPDATE users SET display_name = ${fromClientName}, updated_at = NOW()
          WHERE id = ${userRow.id}
        `;
        userRow = { ...userRow, display_name: fromClientName };
      }
    }

    const session = await createSession(userRow.id);
    if (!session) {
      json(res, 500, { error: 'Could not create session.' });
      return;
    }

    json(res, 200, {
      token: session.id,
      user: {
        uid: String(userRow.id),
        email: userRow.email ?? null,
        displayName: userRow.display_name ?? null,
        phone: userRow.phone ?? null,
        isAdmin: Boolean(userRow.is_admin),
        points: Number(userRow.points ?? 0),
      },
    });
  } catch (err) {
    console.error('[auth/apple]', err);
    json(res, 500, { error: 'Sign in with Apple failed.' });
  }
}
