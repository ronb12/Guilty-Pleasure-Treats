/**
 * Health check for Vercel / load balancers.
 * GET /api/health
 * Does not import db.js or apns2 so it always loads; env-only flags for DB and APNs.
 */
function apnsConfiguredFromEnv() {
  return !!(
    process.env.APNS_KEY_P8 &&
    process.env.APNS_KEY_ID &&
    process.env.APNS_TEAM_ID &&
    process.env.APNS_BUNDLE_ID
  );
}

export default function handler(req, res) {
  const hasDb = !!(process.env.NEON_POOL_URL || process.env.POSTGRES_URL || process.env.DATABASE_URL);
  const neonAuth = !!(process.env.NEON_AUTH_URL && String(process.env.NEON_AUTH_URL).trim());
  res.setHeader('Content-Type', 'application/json');
  res.status(200).json({
    ok: true,
    service: 'Guilty Pleasure Treats API',
    database: hasDb,
    neonAuthConfigured: neonAuth,
    apnsConfigured: apnsConfiguredFromEnv(),
    apnsSandbox: process.env.APNS_SANDBOX === 'true',
    timestamp: new Date().toISOString(),
  });
}
