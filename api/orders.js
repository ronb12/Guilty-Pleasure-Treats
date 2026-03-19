/**
 * GET /api/orders — list orders (admin only, or filter by userId for own orders).
 * POST /api/orders — create order (checkout). Body: userId?, customerName, customerPhone, items, subtotal, tax, total, fulfillmentType, status?, ...
 */
import { sql, hasDb } from '../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { computeOrderTotals, orderTotalsToDollars, normalizeFulfillmentType, toCents } from './lib/orderTotals.js';

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

  if ((req.method || '').toUpperCase() === 'GET') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
    const isAdmin = session.isAdmin === true;
    const userIdFilter = (req.query?.userId ?? '').toString().trim() || null;

    if (!hasDb() || !sql) return res.status(200).json([]);
    try {
      let rows;
      if (isAdmin && !userIdFilter) {
        rows = await sql`
          SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
                 subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
                 stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
                 custom_cake_order_ids, ai_cake_design_ids
          FROM orders
          ORDER BY created_at DESC NULLS LAST
          LIMIT 500
        `;
      } else {
        const uid = isAdmin ? userIdFilter : session.userId;
        if (!uid) return res.status(200).json([]);
        rows = await sql`
          SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
                 subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
                 stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
                 custom_cake_order_ids, ai_cake_design_ids
          FROM orders
          WHERE user_id::text = ${String(uid)}
          ORDER BY created_at DESC NULLS LAST
          LIMIT 200
        `;
      }
      return res.status(200).json((rows || []).map(rowToOrder));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[orders] GET', err);
      return res.status(500).json({ error: 'Failed to fetch orders' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
    const body = req.body || {};
    const requestId = req.headers?.['x-vercel-request-id']
      ?? req.headers?.['x-vercel-id']
      ?? req.headers?.['x-request-id']
      ?? req.headers?.['x-correlation-id']
      ?? null;
    const customerName = String(body.customerName ?? body.customer_name ?? '').trim();
    const customerPhone = String(body.customerPhone ?? body.customer_phone ?? '').trim();
    const items = Array.isArray(body.items) ? body.items : [];
    const subtotal = Number(body.subtotal ?? 0);
    const tax = Number(body.tax ?? 0);
    const total = Number(body.total ?? 0);
    const fulfillmentType = String(body.fulfillmentType ?? body.fulfillment_type ?? 'Pickup').trim();
    if (!customerName || !customerPhone) return res.status(400).json({ error: 'customerName and customerPhone are required' });

    const userId = body.userId != null ? (body.userId === '' ? null : String(body.userId)) : null;
    const customerEmail = body.customerEmail ?? body.customer_email ?? null;
    const deliveryAddress = body.deliveryAddress ?? body.delivery_address ?? null;
    const scheduledPickupDate = body.scheduledPickupDate ?? body.scheduled_pickup_date ?? null;
    const status = String(body.status ?? 'Pending').trim();
    const stripePaymentIntentId = body.stripePaymentIntentId ?? body.stripe_payment_intent_id ?? null;
    const estimatedReadyTime = body.estimatedReadyTime ?? body.estimated_ready_time ?? null;
    const customCakeOrderIds = Array.isArray(body.customCakeOrderIds) ? body.customCakeOrderIds : (Array.isArray(body.custom_cake_order_ids) ? body.custom_cake_order_ids : null);
    const aiCakeDesignIds = Array.isArray(body.aiCakeDesignIds) ? body.aiCakeDesignIds : (Array.isArray(body.ai_cake_design_ids) ? body.ai_cake_design_ids : null);

    const itemsJson = items.map((i) => ({
      id: i.id,
      productId: i.productId,
      name: i.name,
      price: Number(i.price ?? 0),
      quantity: Number(i.quantity ?? 0),
      specialInstructions: i.specialInstructions ?? '',
    }));

    try {
      // Validate/normalize fulfillment early (so we can validate delivery address too).
      const normalizedFulfillmentType = normalizeFulfillmentType(fulfillmentType);
      const deliveryAddressStr = deliveryAddress == null ? '' : String(deliveryAddress).trim();
      const hasDeliveryAddress = deliveryAddressStr.length > 0;
      const deliveryAddressClean = hasDeliveryAddress ? deliveryAddressStr : null;

      if ((normalizedFulfillmentType === 'Delivery' || normalizedFulfillmentType === 'Shipping') && !deliveryAddressClean) {
        return res.status(400).json({ error: 'Delivery address is required. Please try again.', details: [{ requestId }] });
      }
      if (normalizedFulfillmentType === 'Pickup' && deliveryAddressClean) {
        return res.status(400).json({ error: 'Pickup orders must not include a delivery address. Please try again.', details: [{ requestId }] });
      }

      // Compute/validate totals server-side from business settings.
      const [settingsRow] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
      const v = settingsRow?.value_json ?? {};
      const taxRate = v.tax_rate_percent != null ? Number(v.tax_rate_percent) / 100 : 0.08;
      const deliveryFee = v.delivery_fee != null ? Number(v.delivery_fee) : 0;
      const shippingFee = v.shipping_fee != null ? Number(v.shipping_fee) : 0;

      // Sanity check: client discounted subtotal should not be greater than item subtotal.
      // (We allow slight cents drift.)
      const itemsSubtotalCents = items.reduce((sum, i) => {
        const price = Number(i?.price ?? 0);
        const qty = Number(i?.quantity ?? 0);
        if (!Number.isFinite(price) || !Number.isFinite(qty)) return sum;
        const cents = Math.round(price * 100);
        const q = Math.trunc(qty);
        if (q < 0) return sum;
        return sum + cents * q;
      }, 0);
      const discountedSubtotalCents = toCents(subtotal, 'subtotal');
      if (discountedSubtotalCents > itemsSubtotalCents + 1) {
        return res.status(400).json({
          error: 'Order subtotal looks invalid. Please try again.',
          details: [{ requestId }],
        });
      }

      let totals;
      try {
        totals = computeOrderTotals({
          discountedSubtotal: subtotal,
          totalClient: total,
          taxRate,
          fulfillmentType: normalizedFulfillmentType,
          deliveryFee,
          shippingFee,
        });
      } catch (totErr) {
        console.error('[orders] POST totals validation failed', { requestId, message: totErr?.message });
        return res.status(400).json({ error: 'Invalid order totals. Please try again.', details: [{ requestId }] });
      }

      // Validate client tax matches what the server would compute (prevents tampering).
      const taxClientCents = toCents(tax, 'tax');
      if (Math.abs(taxClientCents - totals.taxCents) > 1) {
        return res.status(400).json({ error: 'Invalid order totals. Please try again.', details: [{ requestId }] });
      }
      const computed = orderTotalsToDollars(totals);

      const [row] = await sql`
        INSERT INTO orders (user_id, customer_name, customer_phone, customer_email, delivery_address, items,
          subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status, stripe_payment_intent_id,
          estimated_ready_time, custom_cake_order_ids, ai_cake_design_ids)
        VALUES (${userId}, ${customerName}, ${customerPhone}, ${customerEmail ?? null}, ${deliveryAddressClean}, ${JSON.stringify(itemsJson)},
          ${computed.subtotal}, ${computed.tax}, ${computed.total}, ${normalizedFulfillmentType}, ${scheduledPickupDate ? new Date(scheduledPickupDate) : null}, ${status}, ${stripePaymentIntentId ?? null},
          ${estimatedReadyTime ? new Date(estimatedReadyTime) : null}, ${customCakeOrderIds}, ${aiCakeDesignIds})
        RETURNING id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
          subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status, stripe_payment_intent_id,
          manual_paid_at, created_at, updated_at, estimated_ready_time, custom_cake_order_ids, ai_cake_design_ids
      `;
      const order = rowToOrder(row);
      return res.status(201).json({ id: order.id, subtotal: order.subtotal, tax: order.tax, total: order.total });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[orders] POST', { requestId, err });
      return res.status(500).json({ error: 'Failed to create order', details: [{ requestId }] });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
