import { neon } from '@neondatabase/serverless';

/**
 * Prefer Neon’s pooled `DATABASE_URL` for Vercel/serverless (dashboard → Connect → pooled string).
 * Unpooled/direct URLs often cause intermittent `fetch failed` / connection errors in short-lived functions.
 */
const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;

let _sql = null;
try {
  _sql = connectionString ? neon(connectionString) : null;
} catch (err) {
  console.error('Neon db init error', err);
}

export const sql = _sql;

export function hasDb() {
  return !!connectionString;
}
