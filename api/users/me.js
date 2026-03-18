/**
 * Explicit route for /api/users/me so Vercel serves it without catch-all.
 * Used for session restore and profile (GET/PATCH).
 */
export { default } from '../../api-src/users/me.js';
