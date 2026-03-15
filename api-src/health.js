import { hasDb } from '../api/lib/db.js';

/**
 * Health check for Vercel / load balancers.
 * GET /api/health
 * Includes database: true/false so you can confirm POSTGRES_URL is set on Vercel.
 */
export default function handler(req, res) {
  res.setHeader('Content-Type', 'application/json');
  res.status(200).json({
    ok: true,
    service: 'Guilty Pleasure Treats API',
    database: hasDb(),
    timestamp: new Date().toISOString(),
  });
}
