/**
 * Reviews: public GET (list, or by orderId); customer POST to add review for their completed order (one per order).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToReview(row) {
  if (!row) return null;
  return {
    id: row.id,
    author: row.author ?? '',
    text: row.text ?? '',
    stars: Number(row.stars ?? 5),
    displayOrder: Number(row.display_order ?? 0),
    orderId: row.order_id ?? null,
    userId: row.user_id ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(200).json([]);
  }

  if (req.method === 'GET') {
    try {
      const orderId = (req.query.orderId || req.query.order_id || '').toString().trim() || null;
      const limit = req.query.limit != null ? Math.min(100, Math.max(1, parseInt(String(req.query.limit), 10) || 50)) : null;
      let rows;
      if (orderId) {
        rows = await sql`SELECT * FROM reviews WHERE order_id = ${orderId} ORDER BY created_at DESC LIMIT 1`;
      } else if (limit) {
        rows = await sql`SELECT * FROM reviews ORDER BY display_order ASC, created_at DESC LIMIT ${limit}`;
      } else {
        rows = await sql`SELECT * FROM reviews ORDER BY display_order ASC, created_at DESC`;
      }
      return res.status(200).json(rows.map(rowToReview));
    } catch (err) {
      if (err?.message && err.message.includes('does not exist')) {
        return res.status(200).json([]);
      }
      console.error('reviews GET', err);
      return res.status(200).json([]);
    }
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session) {
      return res.status(401).json({ error: 'Sign in to leave a review' });
    }
    const body = req.body || {};
    const orderId = (body.orderId || body.order_id || '').toString().trim() || null;
    if (!orderId) return res.status(400).json({ error: 'orderId required' });
    const text = String(body.text ?? '').trim();
    const stars = Math.min(5, Math.max(1, parseInt(body.stars, 10) || 5));
    try {
      const orderRows = await sql`SELECT id, user_id, customer_name, status FROM orders WHERE id = ${orderId} LIMIT 1`;
      const order = orderRows[0];
      if (!order) return res.status(404).json({ error: 'Order not found' });
      const completedStatuses = ['Completed', 'Ready for Pickup'];
      if (!completedStatuses.includes(String(order.status))) {
        return res.status(400).json({ error: 'You can only review orders that are completed or delivered.' });
      }
      const orderUserId = order.user_id != null ? String(order.user_id) : null;
      if (orderUserId && orderUserId !== String(session.userId)) {
        return res.status(403).json({ error: 'You can only review your own orders.' });
      }
      const existing = await sql`SELECT id FROM reviews WHERE order_id = ${orderId} LIMIT 1`;
      if (existing.length > 0) {
        return res.status(400).json({ error: 'You already left a review for this order.' });
      }
      const author = (order.customer_name || '').trim() || (session.displayName || session.email || 'Customer');
      const rows = await sql`
        INSERT INTO reviews (order_id, user_id, author, text, stars, display_order)
        VALUES (${orderId}, ${session.userId}, ${author}, ${text || ' '}, ${stars}, 0)
        RETURNING *
      `;
      return res.status(201).json(rowToReview(rows[0]));
    } catch (err) {
      if (err?.message && err.message.includes('does not exist')) {
        return res.status(503).json({ error: 'Reviews table not set up. Run scripts/run-reviews-events-schema.js.' });
      }
      console.error('reviews POST', err);
      return res.status(500).json({ error: err.message || 'Failed to add review' });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
