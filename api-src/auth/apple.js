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
let appleColumnWarningLogged = false;

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

async function findUserByAppleSubject(sub) {
  try {
    const rows = await sql`
      SELECT id, email, display_name, phone, is_admin, points
      FROM users
      WHERE apple_sub = ${sub}
      LIMIT 1
    `;
    if (rows[0]) return rows[0];
  } catch (e) {
    if (e?.code !== '42703') throw e;
  }
  // Backward compatibility: older schemas use apple_id instead of apple_sub.
  const rows = await sql`
    SELECT id, email, display_name, phone, is_admin, points
    FROM users
    WHERE apple_id = ${sub}
    LIMIT 1
  `;
  return rows[0] || null;
}

async function insertUserForAppleSubject({ sub, tokenEmail, displayName }) {
  try {
    const inserted = await sql`
      INSERT INTO users (email, display_name, apple_sub, points, is_admin)
      VALUES (${tokenEmail || null}, ${displayName || null}, ${sub}, 0, false)
      RETURNING id, email, display_name, phone, is_admin, points
    `;
    return inserted[0] || null;
  } catch (e) {
    if (e?.code !== '42703') throw e;
  }
  const inserted = await sql`
    INSERT INTO users (email, display_name, apple_id, points, is_admin)
    VALUES (${tokenEmail || null}, ${displayName || null}, ${sub}, 0, false)
    RETURNING id, email, display_name, phone, is_admin, points
  `;
  return inserted[0] || null;
}

async function logAppleSchemaWarningOnce() {
  if (appleColumnWarningLogged) return;
  try {
    const cols = await sql`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users'
        AND column_name IN ('apple_sub', 'apple_id')
    `;
    const names = new Set(cols.map((c) => c.column_name));
    if (!names.has('apple_sub') && names.has('apple_id')) {
      console.warn('[auth/apple] users.apple_id detected without users.apple_sub. Legacy fallback active; run apple column migration.');
    } else if (!names.has('apple_sub') && !names.has('apple_id')) {
      console.warn('[auth/apple] users table has no apple_sub/apple_id column. Apple login will fail until schema is updated.');
    }
    appleColumnWarningLogged = true;
  } catch (e) {
    // Non-fatal: keep auth path working even if info_schema is unavailable.
    console.warn('[auth/apple] could not verify apple column schema', e?.message || e);
  }
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
  await logAppleSchemaWarningOnce();

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
    // Gated: set AUTH_DEBUG_APPLE=1 on Vercel to log header kid/alg only (no token body).
    const appleDebug =
      process.env.AUTH_DEBUG_APPLE === '1' ||
      /^true$/i.test(String(process.env.AUTH_DEBUG_APPLE || '').trim());
    if (appleDebug) {
      try {
        const hdr = jose.decodeProtectedHeader(identityToken);
        console.error('[auth/apple] jwtVerify failed — header (debug)', {
          kid: hdr.kid ?? null,
          alg: hdr.alg ?? null,
        });
      } catch (_) {
        console.error('[auth/apple] jwtVerify failed — header (debug): could not decode protected header');
      }
    }
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
    let userRow = await findUserByAppleSubject(sub);

    if (!userRow) {
      userRow = await insertUserForAppleSubject({
        sub,
        tokenEmail,
        displayName: fromClientName,
      });
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
