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
  if (typeof value === 'bigint') return value === 1n;
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

/** Store sessions.user_id (TEXT) in the same shape as users.id::text so JOINs match. */
export function canonicalUserIdForSession(userId) {
  if (userId == null) return '';
  let raw = String(userId).trim().replace(/^\{|\}$/g, '').trim();
  const hex = raw.replace(/-/g, '').toLowerCase();
  if (hex.length === 32 && /^[0-9a-f]+$/.test(hex)) {
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
  }
  return raw;
}

/**
 * True if DB says admin, or session email is in ADMIN_GRANT_EMAILS (comma-separated, case-insensitive).
 * Set in Vercel when `users.is_admin` was never set for the owner row.
 */
export function sessionHasAdminAccess(session) {
  if (!session?.userId) return false;
  if (coerceAdminFlag(session.isAdmin)) return true;
  const email = session.email;
  if (!email || typeof email !== 'string') return false;
  const list = (process.env.ADMIN_GRANT_EMAILS || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  if (list.length === 0) return false;
  return list.includes(email.trim().toLowerCase());
}

/**
 * Same as sessionHasAdminAccess, then reads `users.is_admin` by session.userId when the in-memory flag is wrong
 * (JWT/session drift, driver types). Use for mutating admin routes so UI “admin” matches Neon.
 */
export async function sessionHasAdminAccessResolved(session, sqlTag) {
  if (!session?.userId) return false;
  if (sessionHasAdminAccess(session)) return true;
  if (!sqlTag) return false;
  const rawUid = String(session.userId).trim();
  if (!rawUid) return false;
  const canon = canonicalUserIdForSession(rawUid);
  const rows = await awaitNeonRows(
    sqlTag`
      SELECT is_admin FROM users u
      WHERE lower(u.id::text) = lower(${canon})
         OR lower(u.id::text) = lower(${rawUid})
         OR lower(replace(u.id::text, '-', '')) = lower(replace(${rawUid}, '-', ''))
      LIMIT 1
    `,
    'session_resolve_is_admin'
  );
  return coerceAdminFlag(rows[0]?.is_admin);
}

export async function createSession(userId) {
  if (!hasDb() || !sql) return null;
  const uid = canonicalUserIdForSession(userId);
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
  const sid = sessionId != null ? String(sessionId).trim() : '';
  if (!sid) return null;
  try {
    if (isJWT(sid)) {
      const payload = await verifyNeonJWT(sid);
      if (!payload) return null;
      const user = await getOrCreateUserFromNeonPayload(payload);
      if (!user) return null;
      // Authoritative row refresh (avoids stale is_admin / email if lookup path drifted).
      const pid = user.id != null ? String(user.id).trim() : '';
      const freshList =
        pid.length > 0
          ? await awaitNeonRows(
              sql`
            SELECT id, email, display_name, phone, is_admin, points
            FROM users
            WHERE lower(id::text) = lower(${pid})
               OR lower(replace(id::text, '-', '')) = lower(replace(${pid}, '-', ''))
            LIMIT 1
          `,
              'getSession_jwt_user_refresh'
            )
          : [];
      const u = freshList[0] || user;
      const jwtUid = canonicalUserIdForSession(u.id) || String(u.id).trim();
      if (!jwtUid) return null;
      return {
        id: sid,
        userId: jwtUid,
        expiresAt: null,
        email: u.email,
        displayName: u.display_name,
        phone: u.phone ?? null,
        isAdmin: coerceAdminFlag(u.is_admin),
        points: u.points ?? 0,
      };
    }
    if (!hasDb() || !sql) return null;
    // Two-step lookup: sessions.user_id is TEXT; avoid a single JOIN missing rows when UUID text formats differ.
    const sessRows = await awaitNeonRows(
      sql`
      SELECT id, user_id, expires_at FROM sessions
      WHERE id = ${sid} AND expires_at > NOW()
      LIMIT 1
    `,
      'getSession_sess'
    );
    const srow = sessRows[0];
    if (!srow) return null;
    const rawUid = String(srow.user_id ?? '').trim();
    if (!rawUid) return null;
    const canon = canonicalUserIdForSession(rawUid);
    const userRows = await awaitNeonRows(
      sql`
      SELECT id, email, display_name, phone, is_admin, points
      FROM users u
      WHERE lower(u.id::text) = lower(${canon})
         OR lower(u.id::text) = lower(${rawUid})
         OR lower(replace(u.id::text, '-', '')) = lower(replace(${rawUid}, '-', ''))
      LIMIT 1
    `,
      'getSession_user'
    );
    const row = userRows[0];
    if (!row) return null;
    const resolvedUid = row.id != null ? String(row.id).trim() : '';
    if (!resolvedUid) return null;
    return {
      id: srow.id,
      userId: resolvedUid,
      expiresAt: srow.expires_at,
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

/**
 * Resolves to session or null; never rejects.
 * Double `.catch` avoids rare unhandledRejection when Neon’s fetch fails (Vercel logs showed rejection escaping async/await).
 */
export function getSession(sessionId) {
  return Promise.resolve()
    .then(() => getSessionImpl(sessionId))
    .catch((err) => {
      console.error('[auth] getSession rejected', err?.message ?? err);
      return null;
    });
}

export async function deleteSession(sessionId) {
  const sid = sessionId != null ? String(sessionId).trim() : '';
  if (!sid || !hasDb() || !sql) return;
  try {
    await sql`DELETE FROM sessions WHERE id = ${sid}`;
  } catch (err) {
    console.error('[auth] deleteSession', err?.message ?? err);
  }
}

/** Get Bearer token from Authorization header or cookie */
export function getTokenFromRequest(req) {
  const auth = req.headers?.authorization;
  if (auth && /^Bearer\s+/i.test(String(auth))) {
    return String(auth).replace(/^Bearer\s+/i, '').trim();
  }
  const cookie = req.headers?.cookie;
  if (cookie) {
    const m = cookie.match(/\bsession=([^;]+)/);
    if (m) {
      try {
        return decodeURIComponent(m[1].trim());
      } catch {
        return m[1].trim();
      }
    }
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
export function getAuth(req) {
  return Promise.resolve()
    .then(() => getAuthImpl(req))
    .catch((err) => {
      console.error('[auth] getAuth rejected', err?.message ?? err);
      return null;
    });
}

/**
 * Admin mutating routes: valid session + is_admin.
 * Uses the same source as getSession (sessions↔users JOIN or Neon Auth user row) — no second users query,
 * which avoided false 403s when a follow-up SELECT failed or id::text did not match the JOIN.
 */
export function getAdminAuth(req) {
  return Promise.resolve()
    .then(async () => {
      const token = getTokenFromRequest(req);
      if (!token) return null;
      const session = await getSession(token);
      if (!session?.userId) return null;
      const uid = String(session.userId).trim();
      if (!uid) return null;
      if (!(await sessionHasAdminAccessResolved(session, sql))) return null;
      return { userId: uid, isAdmin: true };
    })
    .catch((err) => {
      console.error('[auth] getAdminAuth', err?.message ?? err);
      return null;
    });
}
