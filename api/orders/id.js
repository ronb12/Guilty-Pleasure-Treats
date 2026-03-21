/**
 * GET /api/orders/:id — get one order (owner or admin).
 * PATCH /api/orders/:id — update order (status, manualPaidAt, estimatedReadyTime). Admin or owner.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import {
  attemptAwardLoyaltyForCompletedOrder,
  requestSetsStatusToCompleted,
} from '../../api/lib/awardLoyaltyOnOrderCompleted.js';
import { ensureOrdersOptionalColumns } from '../lib/ordersSchema.js';
import { parcelTrackingFieldsFromRow } from '../../api/lib/parcelTrackingUrls.js';

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
    promoCode: row.promo_code != null && String(row.promo_code).trim() !== '' ? String(row.promo_code).trim() : null,
    tipCents: row.tip_cents != null ? Number(row.tip_cents) : 0,
    userPoints: row.user_points != null ? Number(row.user_points) : null,
    ...parcelTrackingFieldsFromRow(row),
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
      await ensureOrdersOptionalColumns(sql);
      const [row] = await sql`
        SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
               subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
               stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
               custom_cake_order_ids, ai_cake_design_ids, promo_code, tip_cents,
               tracking_carrier, tracking_number, tracking_status_detail, tracking_updated_at
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
      await ensureOrdersOptionalColumns(sql);
      const [order] = await sql`SELECT id, user_id FROM orders WHERE id = ${id}`;
      if (!order) return res.status(404).json({ error: 'Order not found' });
      const orderUserId = order.user_id?.toString?.() ?? order.user_id;
      const sessionUserId = session.userId?.toString?.() ?? session.userId;
      if (orderUserId !== sessionUserId && session.isAdmin !== true) return res.status(403).json({ error: 'Forbidden' });

      const body = req.body || {};
      const trackingInBody =
        'trackingCarrier' in body ||
        'tracking_carrier' in body ||
        'trackingNumber' in body ||
        'tracking_number' in body ||
        'trackingStatusDetail' in body ||
        'tracking_status_detail' in body;
      if (trackingInBody && session.isAdmin !== true) {
        return res.status(403).json({ error: 'Forbidden' });
      }
      let didUpdate = false;
      if (body.status != null) {
        await sql`UPDATE orders SET status = ${String(body.status)}, updated_at = NOW() WHERE id = ${id}`;
        didUpdate = true;
        if (requestSetsStatusToCompleted(body.status)) {
          try {
            await attemptAwardLoyaltyForCompletedOrder(sql, id);
          } catch (loyaltyErr) {
            console.error('[orders/id] loyalty award', loyaltyErr);
          }
        }
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
      if (session.isAdmin === true) {
        const hasTC = 'trackingCarrier' in body || 'tracking_carrier' in body;
        const hasTN = 'trackingNumber' in body || 'tracking_number' in body;
        const hasTS = 'trackingStatusDetail' in body || 'tracking_status_detail' in body;
        if (hasTC || hasTN || hasTS) {
          const [cur] = await sql`
            SELECT tracking_carrier, tracking_number, tracking_status_detail FROM orders WHERE id = ${id}
          `;
          let carrier = cur?.tracking_carrier ?? null;
          let number = cur?.tracking_number ?? null;
          let detail = cur?.tracking_status_detail ?? null;
          if (hasTC) {
            const v = body.trackingCarrier ?? body.tracking_carrier;
            carrier = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim().toLowerCase();
          }
          if (hasTN) {
            const v = body.trackingNumber ?? body.tracking_number;
            number = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim();
          }
          if (hasTS) {
            const v = body.trackingStatusDetail ?? body.tracking_status_detail;
            detail = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim();
          }
          if (carrier != null && !['ups', 'fedex', 'usps'].includes(carrier)) {
            return res.status(400).json({ error: 'trackingCarrier must be ups, fedex, or usps' });
          }
          await sql`
            UPDATE orders SET
              tracking_carrier = ${carrier},
              tracking_number = ${number},
              tracking_status_detail = ${detail},
              tracking_updated_at = NOW(),
              updated_at = NOW()
            WHERE id = ${id}
          `;
          didUpdate = true;
        }
      }
      if (!didUpdate) return res.status(400).json({ error: 'No updates provided' });

      const [updated] = await sql`
        SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
               subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
               stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
               custom_cake_order_ids, ai_cake_design_ids, promo_code, tip_cents,
               tracking_carrier, tracking_number, tracking_status_detail, tracking_updated_at
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
