/**
 * PATCH /api/orders/update-status — update order status and/or pickup_time (admin or owner).
 * Body: { orderId: string (uuid), status?: string, pickup_time?: iso date string, ready_by?: iso date string }
 * Status: pending | confirmed | in_progress | ready | completed | cancelled
 */
const { withCors } = require('../../api/lib/cors');
const { getAuth } = require('../../api/lib/auth');
const { sql } = require('../../api/lib/db');

const ALLOWED_STATUSES = ['pending', 'confirmed', 'in_progress', 'ready', 'completed', 'cancelled'];

async function handler(req, res) {
  if (req.method === 'OPTIONS') return withCors(req, res, () => res.status(204).end());
  if (req.method !== 'PATCH' && req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const auth = getAuth(req);
  if (!auth?.userId) return res.status(401).json({ error: 'Unauthorized' });

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
  } catch {
    return res.status(400).json({ error: 'Invalid JSON' });
  }
  const { orderId, status, pickup_time, ready_by } = body;
  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  if (!status && !pickup_time && ready_by === undefined) return res.status(400).json({ error: 'Provide status, pickup_time, or ready_by' });

  if (status && !ALLOWED_STATUSES.includes(status)) return res.status(400).json({ error: 'Invalid status' });

  try {
    const [order] = await sql`SELECT id, user_id FROM orders WHERE id = ${orderId}`;
    if (!order) return res.status(404).json({ error: 'Order not found' });
    const isAdmin = auth.isAdmin === true;
    if (order.user_id !== auth.userId && !isAdmin) return res.status(403).json({ error: 'Forbidden' });

    if (status) await sql`UPDATE orders SET status = ${status} WHERE id = ${orderId}`;
    if (pickup_time !== undefined) await sql`UPDATE orders SET pickup_time = ${pickup_time ? new Date(pickup_time) : null} WHERE id = ${orderId}`;
    if (ready_by !== undefined) await sql`UPDATE orders SET ready_by = ${ready_by ? new Date(ready_by) : null} WHERE id = ${orderId}`;

    if (status && order.user_id) {
      try {
        const tokenRows = await sql`SELECT device_token FROM push_tokens WHERE user_id = ${order.user_id} LIMIT 1`;
        const deviceToken = tokenRows?.[0]?.device_token;
        if (deviceToken) {
          const { notifyOrderStatusUpdate } = await import('../../api/lib/apns.js');
          await notifyOrderStatusUpdate(deviceToken, orderId, status);
        }
      } catch (e) {
        console.warn('[orders/update-status] push', e?.message ?? e);
      }
    }

    const [updated] = await sql`SELECT * FROM orders WHERE id = ${orderId}`;
    return res.status(200).json(updated);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = handler;
