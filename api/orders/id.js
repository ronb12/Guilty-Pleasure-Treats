/**
 * GET /api/orders/:id — get one order (owner or admin).
 * PATCH /api/orders/:id — update order (status, manualPaidAt, estimatedReadyTime). Admin or owner.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToOrder(row) {
  if (!row) return null;
  const items = Array.isArray(row.items) ? row.items : (typeof row.items === 'object' && row.items !== null ? Object.values(row.items) : []);
  return {
    id: row.id?.toString?.() ?? row.id,
    userId: row.user_id?.toString?.() ?? row.user_id ?? null,
    customerName: row.customer_name ?? '',
    customerPhone: row.customer_phone ?? '',
    customerEmail: row.customer_email ?? null,
    deliveryAddress: row.delivery_address ?? null,
    items: items.map((i) => ({
      id: i?.id ?? i?.productId ?? '',
      productId: i?.productId ?? i?.product_id ?? '',
      name: i?.name ?? '',
      price: Number(i?.price ?? 0),
      quantity: Number(i?.quantity ?? 0),
      specialInstructions: i?.specialInstructions ?? i?.special_instructions ?? '',
    })),
    subtotal: Number(row.subtotal ?? 0),
    tax: Number(row.tax ?? 0),
    total: Number(row.total ?? 0),
    fulfillmentType: row.fulfillment_type ?? 'Pickup',
    scheduledPickupDate: row.scheduled_pickup_date ? new Date(row.scheduled_pickup_date).toISOString() : null,
    status: row.status ?? 'Pending',
    stripePaymentIntentId: row.stripe_payment_intent_id ?? null,
    manualPaidAt: row.manual_paid_at ? new Date(row.manual_paid_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    estimatedReadyTime: row.estimated_ready_time ? new Date(row.estimated_ready_time).toISOString() : null,
    customCakeOrderIds: Array.isArray(row.custom_cake_order_ids) ? row.custom_cake_order_ids : null,
    aiCakeDesignIds: Array.isArray(row.ai_cake_design_ids) ? row.ai_cake_design_ids : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'Order id required' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const [row] = await sql`
        SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
               subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
               stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
               custom_cake_order_ids, ai_cake_design_ids
        FROM orders WHERE id = ${id}
      `;
      if (!row) return res.status(404).json({ error: 'Order not found' });
      const orderUserId = row.user_id?.toString?.() ?? row.user_id;
      const sessionUserId = session.userId?.toString?.() ?? session.userId;
      if (orderUserId !== sessionUserId && session.isAdmin !== true) return res.status(403).json({ error: 'Forbidden' });
      return res.status(200).json(rowToOrder(row));
    } catch (err) {
      console.error('[orders/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch order' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    try {
      const [order] = await sql`SELECT id, user_id FROM orders WHERE id = ${id}`;
      if (!order) return res.status(404).json({ error: 'Order not found' });
      const orderUserId = order.user_id?.toString?.() ?? order.user_id;
      const sessionUserId = session.userId?.toString?.() ?? session.userId;
      if (orderUserId !== sessionUserId && session.isAdmin !== true) return res.status(403).json({ error: 'Forbidden' });

      const body = req.body || {};
      let didUpdate = false;
      if (body.status != null) {
        await sql`UPDATE orders SET status = ${String(body.status)}, updated_at = NOW() WHERE id = ${id}`;
        didUpdate = true;
      }
      if (body.manualPaidAt != null || body.manual_paid_at !== undefined) {
        const v = body.manualPaidAt ?? body.manual_paid_at;
        await sql`UPDATE orders SET manual_paid_at = ${v ? new Date(v) : null}, updated_at = NOW() WHERE id = ${id}`;
        didUpdate = true;
      }
      if (body.estimatedReadyTime != null || body.estimated_ready_time !== undefined) {
        const v = body.estimatedReadyTime ?? body.estimated_ready_time;
        await sql`UPDATE orders SET estimated_ready_time = ${v ? new Date(v) : null}, updated_at = NOW() WHERE id = ${id}`;
        didUpdate = true;
      }
      if (!didUpdate) return res.status(400).json({ error: 'No updates provided' });

      const [updated] = await sql`
        SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
               subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
               stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
               custom_cake_order_ids, ai_cake_design_ids
        FROM orders WHERE id = ${id}
      `;
      return res.status(200).json(rowToOrder(updated) ?? { id });
    } catch (err) {
      console.error('[orders/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update order' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
