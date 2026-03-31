/**
 * Re-export shared Neon client from `api/lib/db.js` (source of truth; excluded from vercel:sync).
 * Handlers that import `../lib/db.js` get the same timeout, retry, and pooler warnings as `api/lib/db.js`.
 */
export { sql, hasDb, awaitNeonRows } from '../../api/lib/db.js';
