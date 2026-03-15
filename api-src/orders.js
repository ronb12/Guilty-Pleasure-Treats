import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';

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

  if (req.method === 'GET') {
    if (!hasDb() || !sql) {
      return res.status(200).json([]);
    }
    try {
      const userId = (req.query || {}).userId;
      const rows = userId
        ? await sql`SELECT * FROM orders WHERE user_id = ${userId} ORDER BY created_at DESC LIMIT 100`
        : await sql`SELECT * FROM orders ORDER BY created_at DESC LIMIT 100`;
      const orders = rows.map(rowToOrder);
      return res.status(200).json(orders);
    } catch (err) {
      console.error('orders GET', err);
      return res.status(500).json({ error: 'Failed to fetch orders', details: err.message });
    }
  }

  if (req.method === 'POST') {
    const body = req.body || {};
    if (!hasDb() || !sql) {
      return res.status(201).json({
        id: `ord_${Date.now()}`,
        message: 'Order received (no database). Connect Neon Postgres in Vercel to persist.',
        items: body.items || [],
      });
    }
    try {
      const items = Array.isArray(body.items) ? body.items : [];
      const subtotal = Number(body.subtotal) || 0;
      const tax = Number(body.tax) || 0;
      const total = Number(body.total) || subtotal + tax;
      const now = new Date().toISOString();
      const rows = await sql`
        INSERT INTO orders (
          user_id, customer_name, customer_phone, items, subtotal, tax, total,
          fulfillment_type, scheduled_pickup_date, status, stripe_payment_intent_id,
          manual_paid_at, created_at, updated_at, estimated_ready_time,
          custom_cake_order_ids, ai_cake_design_ids
        ) VALUES (
          ${body.userId ?? null},
          ${body.customerName ?? ''},
          ${body.customerPhone ?? ''},
          ${JSON.stringify(items)},
          ${subtotal},
          ${tax},
          ${total},
          ${body.fulfillmentType ?? 'Pickup'},
          ${body.scheduledPickupDate ? new Date(body.scheduledPickupDate) : null},
          ${body.status ?? 'Pending'},
          ${body.stripePaymentIntentId ?? null},
          null,
          ${now}::timestamptz,
          ${now}::timestamptz,
          ${body.estimatedReadyTime ? new Date(body.estimatedReadyTime) : null},
          ${body.customCakeOrderIds ? JSON.stringify(body.customCakeOrderIds) : null},
          ${body.aiCakeDesignIds ? JSON.stringify(body.aiCakeDesignIds) : null}
        )
        RETURNING id, created_at
      `;
      const row = rows[0];
      if (!row) {
        return res.status(500).json({ error: 'Failed to create order' });
      }
      return res.status(201).json({ id: row.id, createdAt: row.created_at });
    } catch (err) {
      console.error('orders POST', err);
      return res.status(500).json({ error: 'Failed to create order', details: err.message });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
