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

function adminGrantEmailList() {
  return (process.env.ADMIN_GRANT_EMAILS || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

/** True if `email` is listed in ADMIN_GRANT_EMAILS (case-insensitive). */
function emailMatchesAdminGrant(email) {
  const list = adminGrantEmailList();
  if (list.length === 0 || !email || typeof email !== 'string') return false;
  return list.includes(email.trim().toLowerCase());
}

/**
 * True if `session.userId` matches an id in ADMIN_GRANT_USER_IDS (comma-separated UUIDs, optional).
 * Use when `users.email` is null/private-relay but you still need admin APIs (Neon row must match this id).
 */
function userIdMatchesAdminGrantList(userId) {
  const raw = process.env.ADMIN_GRANT_USER_IDS || '';
  const parts = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (parts.length === 0 || userId == null) return false;
  const uid = String(userId).trim();
  if (!uid) return false;
  const canon = canonicalUserIdForSession(uid);
  const strip = (s) => String(s).replace(/-/g, '').toLowerCase();
  const us = strip(uid);
  const cs = strip(canon);
  for (const p of parts) {
    const pt = p.trim();
    if (!pt) continue;
    const pc = canonicalUserIdForSession(pt);
    if (uid === pt || uid === pc || canon === pt || canon === pc) return true;
    if (us && (us === strip(pt) || us === strip(pc))) return true;
    if (cs && (cs === strip(pt) || cs === strip(pc))) return true;
  }
  return false;
}

/**
 * True if DB says admin, or session email is in ADMIN_GRANT_EMAILS (comma-separated, case-insensitive).
 * Set in Vercel when `users.is_admin` was never set for the owner row.
 */
export function sessionHasAdminAccess(session) {
  if (!session?.userId) return false;
  if (coerceAdminFlag(session.isAdmin)) return true;
  if (emailMatchesAdminGrant(session.email)) return true;
  return userIdMatchesAdminGrantList(session.userId);
}

/**
 * Same as sessionHasAdminAccess, then reads `users.is_admin` (+ email) by session.userId when the in-memory flag is wrong
 * (JWT/session drift, driver types). Also applies ADMIN_GRANT_EMAILS to the DB email when session.email was empty.
 * `session.isAdmin` on the object returned by getSession is computed with this helper so it matches /api/users/me.
 * `neon_auth_id` is queried in a second statement so a missing column cannot invalidate the whole lookup.
 */
export async function sessionHasAdminAccessResolved(session, sqlTag) {
  if (!session?.userId) return false;
  // Same coercion as sessionHasAdminAccess (avoids wrong results if is_admin is a string, etc.).
  if (coerceAdminFlag(session.isAdmin)) return true;
  if (sessionHasAdminAccess(session)) return true;
  if (!sqlTag) return false;
  const rawUid = String(session.userId).trim();
  if (!rawUid) return false;
  const canon = canonicalUserIdForSession(rawUid);
  const rows = await awaitNeonRows(
    sqlTag`
      SELECT is_admin, email FROM users u
      WHERE lower(u.id::text) = lower(${canon})
         OR lower(u.id::text) = lower(${rawUid})
         OR lower(replace(u.id::text, '-', '')) = lower(replace(${rawUid}, '-', ''))
         OR (
           u.neon_auth_id IS NOT NULL
           AND (
             TRIM(u.neon_auth_id) = TRIM(${rawUid})
             OR LOWER(TRIM(u.neon_auth_id)) = LOWER(TRIM(${rawUid}))
             OR REPLACE(TRIM(u.neon_auth_id), '-', '') = REPLACE(TRIM(${rawUid}), '-', '')
           )
         )
      LIMIT 1
    `,
    'session_resolve_is_admin'
  );
  const row = rows[0];
  if (!row) return false;
  if (coerceAdminFlag(row.is_admin)) return true;
  if (emailMatchesAdminGrant(row.email)) return true;
  return emailMatchesAdminGrant(session.email);
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
      const neonSub = payload.sub != null ? String(payload.sub).trim() : '';
      // Authoritative row refresh (avoids stale is_admin / email if lookup path drifted).
      const pid = user.id != null ? String(user.id).trim() : '';
      let freshList = [];
      if (pid.length > 0) {
        freshList = await awaitNeonRows(
          sql`
            SELECT id, email, display_name, phone, is_admin, points
            FROM users
            WHERE lower(id::text) = lower(${pid})
               OR lower(replace(id::text, '-', '')) = lower(replace(${pid}, '-', ''))
            LIMIT 1
          `,
          'getSession_jwt_user_refresh'
        );
      }
      if (!freshList[0] && neonSub.length > 0) {
        freshList = await awaitNeonRows(
          sql`
            SELECT id, email, display_name, phone, is_admin, points
            FROM users
            WHERE neon_auth_id IS NOT NULL
              AND (
                TRIM(neon_auth_id) = TRIM(${neonSub})
                OR LOWER(TRIM(neon_auth_id)) = LOWER(TRIM(${neonSub}))
                OR REPLACE(TRIM(neon_auth_id), '-', '') = REPLACE(TRIM(${neonSub}), '-', '')
              )
            LIMIT 1
          `,
          'getSession_jwt_user_refresh_neon'
        );
      }
      const u = freshList[0] || user;
      const jwtUid = canonicalUserIdForSession(u.id) || String(u.id).trim();
      if (!jwtUid) return null;
      const emailFromRow = u.email != null && String(u.email).trim() !== '' ? String(u.email).trim() : null;
      const emailFromJwt =
        payload.email != null && String(payload.email).trim() !== '' ? String(payload.email).trim() : null;
      const sessionEmail = emailFromRow ?? emailFromJwt;
      // Must match /api/users/me and admin mutating routes (DB re-check + ADMIN_GRANT_*), not only sessionHasAdminAccess.
      const isAdmin = sql
        ? await sessionHasAdminAccessResolved(
            {
              userId: jwtUid,
              email: sessionEmail,
              isAdmin: u.is_admin,
            },
            sql
          )
        : sessionHasAdminAccess({
            userId: jwtUid,
            email: sessionEmail,
            isAdmin: u.is_admin,
          });
      return {
        id: sid,
        userId: jwtUid,
        expiresAt: null,
        email: sessionEmail,
        displayName: u.display_name,
        phone: u.phone ?? null,
        isAdmin,
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
    const isAdmin = await sessionHasAdminAccessResolved(
      {
        userId: resolvedUid,
        email: row.email ?? null,
        isAdmin: row.is_admin,
      },
      sql
    );
    return {
      id: srow.id,
      userId: resolvedUid,
      expiresAt: srow.expires_at,
      email: row.email,
      displayName: row.display_name,
      phone: row.phone ?? null,
      isAdmin,
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
