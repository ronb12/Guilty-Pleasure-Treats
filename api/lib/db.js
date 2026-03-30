import { neon } from '@neondatabase/serverless';

/**
 * Prefer Neon’s pooled `DATABASE_URL` for Vercel/serverless (dashboard → Connect → pooled string).
 * Unpooled/direct URLs often cause intermittent `fetch failed` / connection errors in short-lived functions.
 */
const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;

if (connectionString) {
  try {
    const host = new URL(connectionString.replace(/^postgres(ql)?:/i, 'https:')).hostname;
    if (host && /\.neon\.tech$/i.test(host) && !host.includes('pooler')) {
      console.warn(
        '[db] DATABASE_URL host looks unpooled. In Neon → Connect, use the pooled connection string (host contains pooler) on Vercel to reduce fetch failed errors.'
      );
    }
  } catch (_) {
    /* ignore URL parse errors */
  }
}

/** Optional longer timeout for cold starts / flaky edge (merged into neon fetch). */
function neonFetchOptions() {
  const ms = Number(process.env.NEON_FETCH_TIMEOUT_MS || '45000');
  if (!Number.isFinite(ms) || ms <= 0) return {};
  try {
    if (typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function') {
      return { fetchOptions: { signal: AbortSignal.timeout(ms) } };
    }
  } catch (_) {}
  return {};
}

let _sql = null;
try {
  _sql = connectionString ? neon(connectionString, { ...neonFetchOptions() }) : null;
} catch (err) {
  console.error('Neon db init error', err);
}

export const sql = _sql;

export function hasDb() {
  return !!connectionString;
}

/**
 * Await a neon tagged-template query; never throws. On NeonDbError / fetch failures returns [] so callers don’t crash serverless.
 */
export async function awaitNeonRows(queryPromise, label = 'query') {
  const result = await Promise.resolve(queryPromise).catch((err) => {
    console.error(`[db] ${label}`, err?.message ?? err);
    return [];
  });
  return Array.isArray(result) ? result : [];
}
