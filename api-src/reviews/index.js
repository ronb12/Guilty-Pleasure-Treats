/**
 * GET /api/reviews - list reviews (newest first). Query ?orderId=xxx with auth returns current user's review for that order only.
 * POST /api/reviews - submit order review (auth required). Body: { orderId, rating (1-5), text? }. One review per order per user.
 */
import { sql, hasDb } from '../lib/db.js';
import { getAuth } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToReview(row) {
  if (!row) return null;
  return {
    id: row.id,
    author_name: row.author_name ?? null,
    rating: row.rating != null ? Number(row.rating) : null,
    text: row.text ?? null,
    product_id: row.product_id ?? null,
    order_id: row.order_id?.toString?.() ?? row.order_id ?? null,
    user_id: row.user_id ?? null,
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

  if ((req.method || '').toUpperCase() === 'GET') {
    if (!hasDb() || !sql) return res.status(200).json([]);
    const orderId = (req.query?.orderId ?? '').toString().trim() || null;
    const auth = await getAuth(req);

    try {
      if (orderId && auth?.userId) {
        const rows = await sql`
          SELECT r.id, COALESCE(u.display_name, r.author_name) AS author_name, r.rating, r.text, r.product_id, r.order_id, r.user_id, r.created_at
          FROM reviews r
          LEFT JOIN users u ON (u.id)::text = (r.user_id)::text
          WHERE (r.order_id)::text = ${orderId} AND (r.user_id)::text = ${auth.userId}
          ORDER BY r.created_at DESC
          LIMIT 1
        `;
        return res.status(200).json(rows.length ? [rowToReview(rows[0])] : []);
      }
      const rows = await sql`
        SELECT r.id, COALESCE(u.display_name, r.author_name) AS author_name, r.rating, r.text, r.product_id, r.order_id, r.user_id, r.created_at
        FROM reviews r
        LEFT JOIN users u ON (u.id)::text = (r.user_id)::text
        ORDER BY r.created_at DESC
        LIMIT 100
      `;
      return res.status(200).json(rows.map(rowToReview));
    } catch (err) {
      // Gracefully handle schema drift in production (missing table/column, type mismatch, invalid casts).
      if (['42P01', '42703', '42883', '22P02'].includes(err?.code)) return res.status(200).json([]);
      console.error('[reviews] GET', err);
      return res.status(500).json({ error: 'Failed to fetch reviews' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const auth = await getAuth(req);
    if (!auth?.userId) return res.status(401).json({ error: 'Sign in to leave a review' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

    const body = req.body || {};
    const orderId = (body.orderId ?? '').toString().trim();
    const rating = body.rating != null ? Number(body.rating) : null;
    const text = body.text != null ? String(body.text).trim() : null;

    if (!orderId) return res.status(400).json({ error: 'orderId is required' });
    if (rating == null || rating < 1 || rating > 5) return res.status(400).json({ error: 'rating must be 1–5' });

    try {
      const [order] = await sql`SELECT id, user_id, status FROM orders WHERE (id)::text = ${orderId}`;
      if (!order) return res.status(404).json({ error: 'Order not found' });
      const orderUserId = order.user_id?.toString?.() ?? String(order.user_id);
      if (orderUserId !== auth.userId) {
        return res.status(403).json({ error: 'You can only review your own order' });
      }
      const completed = (order.status || '').toLowerCase();
      if (completed !== 'completed') {
        return res.status(400).json({ error: 'You can only review completed orders' });
      }

      const [existing] = await sql`
        SELECT id FROM reviews WHERE (order_id)::text = ${orderId} AND (user_id)::text = ${auth.userId} LIMIT 1
      `;
      if (existing) return res.status(409).json({ error: 'You already reviewed this order' });

      const [row] = await sql`
        INSERT INTO reviews (rating, text, order_id, user_id)
        VALUES (${rating}, ${text || null}, ${orderId}, ${auth.userId})
        RETURNING id, rating, text, product_id, order_id, user_id, created_at
      `;
      try {
        const { isApnsConfigured, notifyNewReview } = await import('../../api/lib/apns.js');
        if (isApnsConfigured()) {
          const adminRows = await sql`
            SELECT device_token FROM push_tokens
            WHERE is_admin = true AND device_token IS NOT NULL AND TRIM(device_token) != ''
          `;
          const tokens = (adminRows || []).map((r) => r.device_token).filter(Boolean);
          if (tokens.length) {
            const reviewId = row?.id?.toString?.() ?? String(row.id);
            notifyNewReview(tokens, reviewId, orderId, rating);
          }
        }
      } catch (pushErr) {
        console.warn('[reviews] push', pushErr?.message ?? pushErr);
      }
      return res.status(201).json(rowToReview(row));
    } catch (err) {
      if (err?.code === '23505') return res.status(409).json({ error: 'You already reviewed this order' });
      console.error('[reviews] POST', err);
      return res.status(500).json({ error: 'Failed to submit review' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
