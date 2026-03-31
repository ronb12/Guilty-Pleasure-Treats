/**
 * Neon Auth (Better Auth) integration: JWT verification via JWKS and optional login/signup proxy.
 * Set NEON_AUTH_URL (e.g. https://ep-....neonauth..../neondb/auth) to enable.
 */
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { sql, hasDb, awaitNeonRows } from './db.js';

const NEON_AUTH_URL = process.env.NEON_AUTH_URL?.replace(/\/$/, '');
const JWKS_URL = NEON_AUTH_URL ? `${NEON_AUTH_URL}/.well-known/jwks.json` : null;

/** Origin to send to Neon Auth. Must match a domain you add in Neon Console → Auth → Domains. Use AUTH_ORIGIN for a custom domain. */
function getAuthOrigin() {
  const origin = process.env.AUTH_ORIGIN?.trim();
  if (origin) return origin.replace(/\/$/, '');
  return 'https://guilty-pleasure-treats.vercel.app';
}

let remoteJWKS = null;
function getJWKS() {
  if (!JWKS_URL) return null;
  if (!remoteJWKS) remoteJWKS = createRemoteJWKSet(new URL(JWKS_URL));
  return remoteJWKS;
}

/** Returns true if Neon Auth is configured. */
export function isNeonAuthConfigured() {
  return Boolean(NEON_AUTH_URL);
}

/**
 * Verify a JWT issued by Neon Auth using the JWKS endpoint.
 * Returns the payload (sub, email, name, etc.) or null if invalid.
 */
export async function verifyNeonJWT(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const jwks = getJWKS();
  if (!jwks) return null;
  try {
    const { payload } = await jwtVerify(token, jwks, {
      algorithms: ['EdDSA'],
    });
    return payload;
  } catch {
    return null;
  }
}

/**
 * Get or create our users table row for a Neon Auth user (from JWT payload).
 * Returns { id, email, display_name, phone, is_admin, points } or null.
 * On DB connection errors, returns null (does not throw) so serverless handlers don’t crash.
 */
export async function getOrCreateUserFromNeonPayload(payload) {
  if (!hasDb() || !sql || !payload?.sub) return null;
  try {
    return await getOrCreateUserFromNeonPayloadImpl(payload);
  } catch (e) {
    console.error('[neonAuth] getOrCreateUserFromNeonPayload', e?.message ?? e);
    return null;
  }
}

async function getOrCreateUserFromNeonPayloadImpl(payload) {
  try {
    return await getOrCreateUserFromNeonPayloadImplBody(payload);
  } catch (e) {
    console.error('[neonAuth] getOrCreateUserFromNeonPayloadImpl', e?.message ?? e);
    return null;
  }
}

async function getOrCreateUserFromNeonPayloadImplBody(payload) {
  const neonId = String(payload.sub);
  const email = payload.email ? String(payload.email).trim().toLowerCase() : null;
  const name = payload.name || payload.displayName || null;

  const byNeonId = await awaitNeonRows(
    sql`
      SELECT id, email, display_name, phone, is_admin, points
      FROM users
      WHERE neon_auth_id IS NOT NULL
        AND (
          TRIM(neon_auth_id) = TRIM(${neonId})
          OR LOWER(TRIM(neon_auth_id)) = LOWER(TRIM(${neonId}))
          OR REPLACE(TRIM(neon_auth_id), '-', '') = REPLACE(TRIM(${neonId}), '-', '')
        )
      LIMIT 1
    `,
    'neonAuth_byNeonId'
  );
  if (byNeonId.length > 0) {
    const u = byNeonId[0];
    return { id: u.id, email: u.email, display_name: u.display_name, phone: u.phone ?? null, is_admin: u.is_admin, points: Number(u.points ?? 0) };
  }

  if (email) {
    const byEmail = await awaitNeonRows(
      sql`
      SELECT id, email, display_name, phone, is_admin, points
      FROM users
      WHERE LOWER(TRIM(COALESCE(email, ''))) = ${email}
      LIMIT 1
    `,
      'neonAuth_byEmail'
    );
    if (byEmail.length > 0) {
      const u = byEmail[0];
      await awaitNeonRows(
        sql`UPDATE users SET neon_auth_id = ${neonId}, updated_at = NOW() WHERE id = ${u.id}`,
        'neonAuth_link_neon_id'
      );
      return { id: u.id, email: u.email, display_name: u.display_name, phone: u.phone ?? null, is_admin: u.is_admin, points: Number(u.points ?? 0) };
    }
  }

  try {
    const insertResult = await sql`
      INSERT INTO users (email, display_name, neon_auth_id, is_admin, points)
      VALUES (${email || null}, ${name || null}, ${neonId}, false, 0)
      RETURNING id, email, display_name, phone, is_admin, points
    `;
    const u = insertResult[0];
    return u ? { id: u.id, email: u.email, display_name: u.display_name, phone: u.phone ?? null, is_admin: u.is_admin, points: Number(u.points ?? 0) } : null;
  } catch (e) {
    if (e?.code === '42703') {
      const insertResult = await sql`
        INSERT INTO users (email, display_name, is_admin, points)
        VALUES (${email || null}, ${name || null}, false, 0)
        RETURNING id, email, display_name, phone, is_admin, points
      `;
      const u = insertResult[0];
      return u ? { id: u.id, email: u.email, display_name: u.display_name, phone: u.phone ?? null, is_admin: u.is_admin, points: Number(u.points ?? 0) } : null;
    }
    throw e;
  }
}

/**
 * Proxy sign-in to Neon Auth: POST sign-in/email, then GET token (with cookie), return JWT + user.
 * Never throws. `ok: false` + `phase: 'user_sync'` means Neon accepted credentials but public.users sync failed (DB).
 */
export async function neonAuthSignIn(email, password) {
  if (!NEON_AUTH_URL) return { ok: false, phase: 'config' };
  try {
    const origin = getAuthOrigin();
    const signInRes = await fetch(`${NEON_AUTH_URL}/sign-in/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: origin },
      body: JSON.stringify({
        email: String(email).trim(),
        password: String(password),
      }),
      redirect: 'manual',
    });
    const setCookie = signInRes.headers.get('set-cookie') || signInRes.headers.get('Set-Cookie');
    const cookieValue = setCookie ? setCookie.split(';')[0].trim() : null;
    if (!cookieValue || !signInRes.ok) return { ok: false, phase: 'neon_signin', status: signInRes.status };
    const tokenRes = await fetch(`${NEON_AUTH_URL}/token`, {
      method: 'GET',
      headers: { Cookie: cookieValue },
    });
    if (!tokenRes.ok) return { ok: false, phase: 'token', status: tokenRes.status };
    let tokenJson;
    try {
      tokenJson = await tokenRes.json();
    } catch {
      return { ok: false, phase: 'token_json' };
    }
    const jwt = tokenJson?.token;
    if (!jwt) return { ok: false, phase: 'jwt_missing' };
    const payload = await verifyNeonJWT(jwt);
    if (!payload) return { ok: false, phase: 'jwt_verify' };
    const user = await getOrCreateUserFromNeonPayload(payload);
    if (!user) return { ok: false, phase: 'user_sync' };
    return { ok: true, token: jwt, user };
  } catch (e) {
    console.error('[neonAuth] signIn', e?.message ?? e);
    return { ok: false, phase: 'error', message: String(e?.message || e) };
  }
}

/**
 * Proxy sign-up to Neon Auth: POST sign-up/email, then GET token, return JWT + user.
 */
export async function neonAuthSignUp(email, password, name) {
  if (!NEON_AUTH_URL) return { success: false, statusCode: 503, message: 'Neon Auth not configured' };
  const origin = getAuthOrigin();
  const signUpRes = await fetch(`${NEON_AUTH_URL}/sign-up/email`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: origin },
    body: JSON.stringify({
      email: String(email).trim(),
      password: String(password),
      name: name ? String(name).trim() : undefined,
    }),
    redirect: 'manual',
  });
  let message = '';
  try {
    const text = await signUpRes.text();
    message = (text && text.length < 500) ? text : '';
    if (message) {
      try {
        const j = JSON.parse(text);
        message = j.message || j.error || message;
      } catch (_) {}
    }
  } catch (_) {}
  const setCookie = signUpRes.headers.get('set-cookie') || signUpRes.headers.get('Set-Cookie');
  const cookieValue = setCookie ? setCookie.split(';')[0].trim() : null;
  if (!cookieValue || !signUpRes.ok) {
    const isDuplicate = signUpRes.status === 409 || /already|exists|duplicate|in use/i.test(message);
    return { success: false, statusCode: signUpRes.status || 500, message: message || 'Sign-up failed' };
  }
  const tokenRes = await fetch(`${NEON_AUTH_URL}/token`, {
    method: 'GET',
    headers: { Cookie: cookieValue },
  });
  if (!tokenRes.ok) return { success: false, statusCode: tokenRes.status || 500, message: 'Could not get session' };
  const tokenJson = await tokenRes.json();
  const jwt = tokenJson?.token;
  if (!jwt) return { success: false, statusCode: 500, message: 'Invalid token response' };
  const payload = await verifyNeonJWT(jwt);
  if (!payload) return { success: false, statusCode: 500, message: 'Invalid token' };
  const user = await getOrCreateUserFromNeonPayload(payload);
  if (!user) return { success: false, statusCode: 500, message: 'Could not create user' };
  return { success: true, token: jwt, user };
}
