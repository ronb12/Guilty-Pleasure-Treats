import { sql, hasDb, awaitNeonRows } from './db.js';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { verifyNeonJWT, getOrCreateUserFromNeonPayload } from './neonAuth.js';

const SESSION_DAYS = 30;
const BCRYPT_ROUNDS = 10;

/** Normalize is_admin from DB/drivers so checks are consistent (avoids `!== true` failing on coercion). */
export function coerceAdminFlag(value) {
  if (value === true) return true;
  if (value === false || value == null) return false;
  if (typeof value === 'number') return value === 1;
  if (typeof value === 'string') {
    const s = value.trim().toLowerCase();
    return s === 'true' || s === 't' || s === '1' || s === 'yes';
  }
  return false;
}

export async function hashPassword(password) {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

export async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export async function createSession(userId) {
  if (!hasDb() || !sql) return null;
  const uid = userId != null ? String(userId) : null;
  if (!uid) return null;
  try {
    const id = randomUUID();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + SESSION_DAYS);
    await sql`
      INSERT INTO sessions (id, user_id, expires_at)
      VALUES (${id}, ${uid}, ${expiresAt})
    `;
    return { id, userId: uid, expiresAt };
  } catch (err) {
    console.error('[auth] createSession', err?.message ?? err);
    return null;
  }
}

/** True if the token looks like a JWT (three base64 parts). */
function isJWT(token) {
  if (!token || typeof token !== 'string') return false;
  const parts = token.split('.');
  return parts.length === 3 && parts.every((p) => p.length > 0);
}

async function getSessionImpl(sessionId) {
  if (!sessionId) return null;
  try {
    if (isJWT(sessionId)) {
      const payload = await verifyNeonJWT(sessionId);
      if (!payload) return null;
      const user = await getOrCreateUserFromNeonPayload(payload);
      if (!user) return null;
      return {
        id: sessionId,
        userId: user.id,
        expiresAt: null,
        email: user.email,
        displayName: user.display_name,
        phone: user.phone ?? null,
        isAdmin: coerceAdminFlag(user.is_admin),
        points: user.points ?? 0,
      };
    }
    if (!hasDb() || !sql) return null;
    const rows = await awaitNeonRows(
      sql`
      SELECT s.id, s.user_id, s.expires_at, u.email, u.display_name, u.phone, u.is_admin, u.points
      FROM sessions s
      JOIN users u ON u.id = s.user_id
      WHERE s.id = ${sessionId} AND s.expires_at > NOW()
      LIMIT 1
    `,
      'getSession'
    );
    const row = rows[0];
    if (!row) return null;
    return {
      id: row.id,
      userId: row.user_id,
      expiresAt: row.expires_at,
      email: row.email,
      displayName: row.display_name,
      phone: row.phone ?? null,
      isAdmin: coerceAdminFlag(row.is_admin),
      points: row.points ?? 0,
    };
  } catch (err) {
    console.error('[auth] getSession', err?.message ?? err);
    return null;
  }
}

/** Resolves to session or null; never rejects (avoids unhandled Neon fetch failures crashing serverless). */
export async function getSession(sessionId) {
  try {
    return await getSessionImpl(sessionId);
  } catch (err) {
    console.error('[auth] getSession rejected', err?.message ?? err);
    return null;
  }
}

export async function deleteSession(sessionId) {
  if (!sessionId || !hasDb() || !sql) return;
  try {
    await sql`DELETE FROM sessions WHERE id = ${sessionId}`;
  } catch (err) {
    console.error('[auth] deleteSession', err?.message ?? err);
  }
}

/** Get Bearer token from Authorization header or cookie */
export function getTokenFromRequest(req) {
  const auth = req.headers?.authorization;
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  const cookie = req.headers?.cookie;
  if (cookie) {
    const m = cookie.match(/\bsession=([^;]+)/);
    if (m) return m[1];
  }
  return null;
}

async function getAuthImpl(req) {
  try {
    const token = getTokenFromRequest(req);
    if (!token) return null;
    const session = await getSession(token);
    if (!session?.userId) return null;
    return { userId: session.userId, isAdmin: coerceAdminFlag(session.isAdmin) };
  } catch (err) {
    console.error('[auth] getAuth', err?.message ?? err);
    return null;
  }
}

/** Never rejects — safe for serverless when Neon returns fetch failed. Always await at call sites. */
export async function getAuth(req) {
  try {
    return await getAuthImpl(req).catch((err) => {
      console.error('[auth] getAuth rejected', err?.message ?? err);
      return null;
    });
  } catch (err) {
    console.error('[auth] getAuth outer', err?.message ?? err);
    return null;
  }
}

/**
 * Admin mutating routes: valid session + is_admin.
 * Uses the same source as getSession (sessions↔users JOIN or Neon Auth user row) — no second users query,
 * which avoided false 403s when a follow-up SELECT failed or id::text did not match the JOIN.
 */
export async function getAdminAuth(req) {
  try {
    const token = getTokenFromRequest(req);
    if (!token) return null;
    const session = await getSession(token);
    if (!session?.userId) return null;
    const uid = String(session.userId).trim();
    if (!uid) return null;
    if (!coerceAdminFlag(session.isAdmin)) return null;
    return { userId: uid, isAdmin: true };
  } catch (err) {
    console.error('[auth] getAdminAuth', err?.message ?? err);
    return null;
  }
}
