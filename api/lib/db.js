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
  const ms = Number(process.env.NEON_FETCH_TIMEOUT_MS || '90000');
  if (!Number.isFinite(ms) || ms <= 0) return {};
  try {
    if (typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function') {
      return { fetchOptions: { signal: AbortSignal.timeout(ms) } };
    }
  } catch (_) {}
  return {};
}

function isTransientDbError(e) {
  const parts = [
    e?.message,
    e?.sourceError?.message,
    e?.cause?.message,
    e?.name,
  ]
    .filter(Boolean)
    .join(' ');
  return /timeout|aborted|fetch failed|ECONNRESET|UND_ERR|ECONNREFUSED|socket hang up|network|TimeoutError|DOMException/i.test(
    parts
  );
}

async function runSqlWithRetry(executor) {
  try {
    return await executor();
  } catch (e) {
    if (!isTransientDbError(e)) throw e;
    await new Promise((r) => setTimeout(r, 500));
    return await executor();
  }
}

let _baseSql = null;
try {
  _baseSql = connectionString ? neon(connectionString, { ...neonFetchOptions() }) : null;
} catch (err) {
  console.error('Neon db init error', err);
}

/** Tagged-template SQL client; one retry on transient connection/timeout errors (Vercel cold start + burst traffic). */
export const sql = _baseSql
  ? function sql(strings, ...values) {
      return runSqlWithRetry(() => _baseSql(strings, ...values));
    }
  : null;

export function hasDb() {
  return !!connectionString;
}

/**
 * Await a neon tagged-template query; never throws. On NeonDbError / fetch failures returns [] so callers don’t crash serverless.
 */
export async function awaitNeonRows(queryPromise, label = 'query') {
  const result = await Promise.resolve(queryPromise).catch((err) => {
    const transient = isTransientDbError(err);
    if (transient) {
      console.warn(`[db] ${label} (transient)`, err?.message ?? err);
    } else {
      console.error(`[db] ${label}`, err?.message ?? err);
    }
    return [];
  });
  return Array.isArray(result) ? result : [];
}
