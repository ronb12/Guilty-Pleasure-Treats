/**
 * Simple in-memory rate limiting for serverless (resets on cold start).
 * Use with caution: not shared across instances; good enough to blunt abuse.
 */

const buckets = new Map();

function prune(now) {
  if (buckets.size < 5000) return;
  for (const [k, v] of buckets) {
    if (now > v.resetAt) buckets.delete(k);
  }
}

export function getClientIp(req) {
  const xf = req.headers?.['x-forwarded-for'];
  if (typeof xf === 'string' && xf.length) {
    return xf.split(',')[0].trim().slice(0, 128);
  }
  const real = req.headers?.['x-real-ip'];
  if (typeof real === 'string' && real.length) return real.trim().slice(0, 128);
  return 'unknown';
}

/**
 * @returns {boolean} true if allowed, false if rate limited
 */
export function checkRateLimit(req, bucketKey, { max, windowMs }) {
  const ip = getClientIp(req);
  const id = `${bucketKey}::${ip}`;
  const now = Date.now();
  prune(now);
  let b = buckets.get(id);
  if (!b || now > b.resetAt) {
    b = { count: 0, resetAt: now + windowMs };
    buckets.set(id, b);
  }
  b.count += 1;
  return b.count <= max;
}
