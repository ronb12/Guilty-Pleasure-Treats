/**
 * Neon Auth (Better Auth) integration: JWT verification via JWKS and optional login/signup proxy.
 * Set NEON_AUTH_URL (e.g. https://ep-....neonauth..../neondb/auth) to enable.
 */
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { sql, hasDb } from './db.js';

const NEON_AUTH_URL = process.env.NEON_AUTH_URL?.replace(/\/$/, '');
const JWKS_URL = NEON_AUTH_URL ? `${NEON_AUTH_URL}/.well-known/jwks.json` : null;

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
 * Returns { id, email, display_name, is_admin, points } or null.
 */
export async function getOrCreateUserFromNeonPayload(payload) {
  if (!hasDb() || !sql || !payload?.sub) return null;
  const neonId = String(payload.sub);
  const email = payload.email ? String(payload.email).trim().toLowerCase() : null;
  const name = payload.name || payload.displayName || null;

  // Prefer lookup by neon_auth_id; fallback to email if column missing
  try {
    const byNeonId = await sql`
      SELECT id, email, display_name, is_admin, points
      FROM users
      WHERE neon_auth_id = ${neonId}
      LIMIT 1
    `;
    if (byNeonId.length > 0) {
      const u = byNeonId[0];
      return { id: u.id, email: u.email, display_name: u.display_name, is_admin: u.is_admin, points: Number(u.points ?? 0) };
    }
  } catch (e) {
    if (e?.code !== '42703') throw e; // column neon_auth_id may not exist
  }

  if (email) {
    const byEmail = await sql`
      SELECT id, email, display_name, is_admin, points
      FROM users
      WHERE email = ${email}
      LIMIT 1
    `;
    if (byEmail.length > 0) {
      const u = byEmail[0];
      try {
        await sql`UPDATE users SET neon_auth_id = ${neonId}, updated_at = NOW() WHERE id = ${u.id}`;
      } catch (_) { /* column may not exist */ }
      return { id: u.id, email: u.email, display_name: u.display_name, is_admin: u.is_admin, points: Number(u.points ?? 0) };
    }
  }

  // Create new user linked to Neon Auth
  try {
    const insertResult = await sql`
      INSERT INTO users (email, display_name, neon_auth_id, is_admin, points)
      VALUES (${email || null}, ${name || null}, ${neonId}, false, 0)
      RETURNING id, email, display_name, is_admin, points
    `;
    const u = insertResult[0];
    return u ? { id: u.id, email: u.email, display_name: u.display_name, is_admin: u.is_admin, points: Number(u.points ?? 0) } : null;
  } catch (e) {
    if (e?.code === '42703') {
      // neon_auth_id column missing: insert without it
      const insertResult = await sql`
        INSERT INTO users (email, display_name, is_admin, points)
        VALUES (${email || null}, ${name || null}, false, 0)
        RETURNING id, email, display_name, is_admin, points
      `;
      const u = insertResult[0];
      return u ? { id: u.id, email: u.email, display_name: u.display_name, is_admin: u.is_admin, points: Number(u.points ?? 0) } : null;
    }
    throw e;
  }
}

/**
 * Proxy sign-in to Neon Auth: POST sign-in/email, then GET token (with cookie), return JWT + user.
 */
export async function neonAuthSignIn(email, password) {
  if (!NEON_AUTH_URL) return null;
  const signInRes = await fetch(`${NEON_AUTH_URL}/sign-in/email`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: String(email).trim(), password: String(password) }),
    redirect: 'manual',
  });
  const setCookie = signInRes.headers.get('set-cookie') || signInRes.headers.get('Set-Cookie');
  const cookieValue = setCookie ? setCookie.split(';')[0].trim() : null;
  if (!cookieValue || !signInRes.ok) return null;
  const tokenRes = await fetch(`${NEON_AUTH_URL}/token`, {
    method: 'GET',
    headers: { Cookie: cookieValue },
  });
  if (!tokenRes.ok) return null;
  const tokenJson = await tokenRes.json();
  const jwt = tokenJson?.token;
  if (!jwt) return null;
  const payload = await verifyNeonJWT(jwt);
  if (!payload) return null;
  const user = await getOrCreateUserFromNeonPayload(payload);
  if (!user) return null;
  return { token: jwt, user };
}

/**
 * Proxy sign-up to Neon Auth: POST sign-up/email, then GET token, return JWT + user.
 */
export async function neonAuthSignUp(email, password, name) {
  if (!NEON_AUTH_URL) return null;
  const signUpRes = await fetch(`${NEON_AUTH_URL}/sign-up/email`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: String(email).trim(),
      password: String(password),
      name: name ? String(name).trim() : undefined,
    }),
    redirect: 'manual',
  });
  const setCookie = signUpRes.headers.get('set-cookie') || signUpRes.headers.get('Set-Cookie');
  const cookieValue = setCookie ? setCookie.split(';')[0].trim() : null;
  if (!cookieValue || !signUpRes.ok) return null;
  const tokenRes = await fetch(`${NEON_AUTH_URL}/token`, {
    method: 'GET',
    headers: { Cookie: cookieValue },
  });
  if (!tokenRes.ok) return null;
  const tokenJson = await tokenRes.json();
  const jwt = tokenJson?.token;
  if (!jwt) return null;
  const payload = await verifyNeonJWT(jwt);
  if (!payload) return null;
  const user = await getOrCreateUserFromNeonPayload(payload);
  if (!user) return null;
  return { token: jwt, user };
}
