/**
 * GET /api/reviews - list reviews (newest first).
 */
import { sql, hasDb } from '../lib/db.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToReview(row) {
  if (!row) return null;
  return {
    id: row.id,
    author_name: row.author_name ?? null,
    rating: row.rating != null ? Number(row.rating) : null,
    text: row.text ?? null,
    product_id: row.product_id ?? null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(200).json([]);
  }
  try {
    const rows = await sql`
      SELECT id, author_name, rating, text, product_id, created_at
      FROM reviews
      ORDER BY created_at DESC
      LIMIT 100
    `;
    return res.status(200).json(rows.map(rowToReview));
  } catch (err) {
    if (err?.code === '42P01') return res.status(200).json([]);
    console.error('[reviews] GET', err);
    return res.status(500).json({ error: 'Failed to fetch reviews' });
  }
}
