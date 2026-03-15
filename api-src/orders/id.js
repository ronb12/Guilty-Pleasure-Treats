import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToOrder(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id ?? null,
    customerName: row.customer_name,
    customerPhone: row.customer_phone,
    items: Array.isArray(row.items) ? row.items : (row.items && typeof row.items === 'object' ? (row.items.items ?? row.items) : []),
    subtotal: Number(row.subtotal),
    tax: Number(row.tax),
    total: Number(row.total),
    fulfillmentType: row.fulfillment_type,
    scheduledPickupDate: row.scheduled_pickup_date ? new Date(row.scheduled_pickup_date).toISOString() : null,
    status: row.status,
    stripePaymentIntentId: row.stripe_payment_intent_id ?? null,
    manualPaidAt: row.manual_paid_at ? new Date(row.manual_paid_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    estimatedReadyTime: row.estimated_ready_time ? new Date(row.estimated_ready_time).toISOString() : null,
    customCakeOrderIds: row.custom_cake_order_ids ?? null,
    aiCakeDesignIds: row.ai_cake_design_ids ?? null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  const id = req.query?.id;
  if (!id) {
    return res.status(400).json({ error: 'Order id required' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    try {
      const rows = await sql`SELECT * FROM orders WHERE id = ${id} LIMIT 1`;
      const order = rows[0] ? rowToOrder(rows[0]) : null;
      if (!order) return res.status(404).json({ error: 'Order not found' });
      return res.status(200).json(order);
    } catch (err) {
      console.error('orders/[id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch order', details: err.message });
    }
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    try {
      let rows = await sql`SELECT * FROM orders WHERE id = ${id} LIMIT 1`;
      if (!rows.length) return res.status(404).json({ error: 'Order not found' });
      let current = rows[0];
      const now = new Date();
      if (body.status !== undefined) {
        await sql`UPDATE orders SET status = ${String(body.status)}, updated_at = ${now} WHERE id = ${id}`;
        current.status = body.status;
      }
      if (body.manualPaidAt !== undefined) {
        const d = body.manualPaidAt ? new Date(body.manualPaidAt) : null;
        await sql`UPDATE orders SET manual_paid_at = ${d}, updated_at = ${now} WHERE id = ${id}`;
        current.manual_paid_at = d;
      }
      if (body.estimatedReadyTime !== undefined) {
        const d = body.estimatedReadyTime ? new Date(body.estimatedReadyTime) : null;
        await sql`UPDATE orders SET estimated_ready_time = ${d}, updated_at = ${now} WHERE id = ${id}`;
        current.estimated_ready_time = d;
      }
      return res.status(200).json(rowToOrder(current));
    } catch (err) {
      console.error('orders/[id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update order', details: err.message });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
