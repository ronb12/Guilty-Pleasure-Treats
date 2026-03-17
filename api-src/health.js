/**
 * Health check for Vercel / load balancers.
 * GET /api/health
 * Does not import db.js so it always loads; use POSTGRES_URL for database flag.
 */
export default function handler(req, res) {
  const hasDb = !!(process.env.POSTGRES_URL || process.env.DATABASE_URL);
  res.setHeader('Content-Type', 'application/json');
  res.status(200).json({
    ok: true,
    service: 'Guilty Pleasure Treats API',
    database: hasDb,
    timestamp: new Date().toISOString(),
  });
}
