import postgres from 'postgres';

/**
 * Vercel often sets POSTGRES_URL (sometimes direct / non-pooler). Use the POOLED string
 * (host contains `pooler`). Prefer pooled DATABASE_URL when POSTGRES_URL is unpooled.
 * Override with NEON_POOL_URL if set.
 */
function hostnameOf(conn) {
  if (!conn || typeof conn !== 'string') return '';
  try {
    return new URL(conn.replace(/^postgres(ql)?:/i, 'https:')).hostname || '';
  } catch {
    return '';
  }
}

function isPooledHost(host) {
  return typeof host === 'string' && host.includes('pooler');
}

function pickNeonConnectionString() {
  const explicit = process.env.NEON_POOL_URL?.trim();
  if (explicit) return explicit;

  const postgresqlUrl = process.env.POSTGRES_URL?.trim();
  const databaseUrl = process.env.DATABASE_URL?.trim();

  const hPg = hostnameOf(postgresqlUrl);
  const hDb = hostnameOf(databaseUrl);
  const pgPooled = isPooledHost(hPg);
  const dbPooled = isPooledHost(hDb);

  if (postgresqlUrl && databaseUrl && dbPooled && !pgPooled) {
    console.warn(
      '[db] Using DATABASE_URL (pooled) instead of POSTGRES_URL (unpooled). Set NEON_POOL_URL or a pooled POSTGRES_URL in Vercel → Env.'
    );
    return databaseUrl;
  }
  if (postgresqlUrl && databaseUrl && pgPooled && !dbPooled) return postgresqlUrl;

  return postgresqlUrl || databaseUrl;
}

/**
 * `channel_binding=require` is for libpq; strip for generic clients to avoid odd TLS edge cases.
 */
function sanitizeConnectionString(raw) {
  if (!raw || typeof raw !== 'string') return raw;
  let s = raw.trim();
  s = s.replace(/[?&]channel_binding=[^&]*/gi, '');
  s = s.replace(/\?&/, '?');
  s = s.replace(/&&+/g, '&');
  // Removing "?channel_binding=...&" can leave "/dbname&sslmode=..." — Postgres then treats the whole path as the db name.
  s = s.replace(/(\/[\w.-]+)&(?=[\w.]+=)/i, '$1?');
  // Broader: "/dbname&sslmode=" (ampersand in path) → "/dbname?sslmode=" — exclude "&" from path segment.
  s = s.replace(/(\/[^/?#&]+)&([a-zA-Z_][a-zA-Z0-9_.-]*=)/g, '$1?$2');
  if (s.endsWith('?') || s.endsWith('&')) s = s.slice(0, -1);
  return s;
}

const connectionString = sanitizeConnectionString(pickNeonConnectionString());

if (connectionString) {
  try {
    const host = hostnameOf(connectionString);
    if (host && /\.neon\.tech$/i.test(host) && !isPooledHost(host)) {
      console.warn(
        '[db] Connection host looks unpooled. Use Neon’s pooled string (hostname contains pooler) on Vercel.'
      );
    }
  } catch (_) {
    /* ignore */
  }
}

const RETRY_DELAYS_MS = [400, 1200, 3000];

function isTransientDbError(e) {
  const code = e?.code;
  if (typeof code === 'string') {
    if (code.startsWith('08')) return true;
    if (code === '57P01' || code === '57P02' || code === '57P03') return true;
  }
  if (code === 'ECONNRESET' || code === 'ETIMEDOUT' || code === 'EPIPE' || code === 'ENOTFOUND') return true;
  const parts = [e?.message, e?.cause?.message, e?.name].filter(Boolean).join(' ');
  return /timeout|aborted|fetch failed|ECONNRESET|ECONNREFUSED|socket hang up|network|Connection terminated|ECONNREFUSED|closed the connection/i.test(
    parts
  );
}

async function runSqlWithRetry(executor) {
  let lastErr;
  for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
    try {
      return await executor();
    } catch (e) {
      lastErr = e;
      if (!isTransientDbError(e) || attempt >= RETRY_DELAYS_MS.length) throw e;
      await new Promise((r) => setTimeout(r, RETRY_DELAYS_MS[attempt]));
    }
  }
  throw lastErr;
}

/** @type {import('postgres').Sql<{}> | null} */
let _rawSql = null;
try {
  if (connectionString) {
    _rawSql = postgres(connectionString, {
      max: 1,
      idle_timeout: 20,
      connect_timeout: Number(process.env.POSTGRES_CONNECT_TIMEOUT_SEC || '45'),
      /**
       * Neon pooler (PgBouncer, transaction mode) does not support prepared statements the same way.
       * Without this, queries can fail or hang intermittently.
       */
      prepare: false,
      ssl: 'require',
      connection: { application_name: 'gpt-vercel' },
    });
  }
} catch (err) {
  console.error('[db] postgres() init error', err);
}

/**
 * Retry only tagged-template calls (real queries). Fragment helpers like sql(array) for IN (...) stay synchronous.
 */
function wrapSql(rawSql) {
  return new Proxy(rawSql, {
    apply(target, thisArg, args) {
      const [first, ...rest] = args;
      if (first?.raw) {
        return runSqlWithRetry(() => Reflect.apply(target, thisArg, args));
      }
      return Reflect.apply(target, thisArg, args);
    },
    get(target, prop, receiver) {
      if (prop === 'then') return undefined;
      const v = Reflect.get(target, prop, receiver);
      if (typeof v === 'function') return v.bind(target);
      return v;
    },
  });
}

export const sql = _rawSql ? wrapSql(_rawSql) : null;

export function hasDb() {
  return !!connectionString;
}

/**
 * Await a query; never throws. On failure returns [] so serverless handlers don’t crash.
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
