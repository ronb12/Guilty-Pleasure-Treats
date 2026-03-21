/**
 * GET /api/orders — list orders (admin only, or filter by userId for own orders).
 * POST /api/orders — create order (checkout). Body: userId?, customerName, customerPhone, items, subtotal, tax, total, fulfillmentType, status?, ...
 */
import { sql, hasDb } from '../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { computeOrderTotals, orderTotalsToDollars, normalizeFulfillmentType, toCents } from './lib/orderTotals.js';
import { checkRateLimit } from './lib/rateLimit.js';
import { evaluatePromotion } from './lib/promoServer.js';
import { ensureOrdersOptionalColumns } from './lib/ordersSchema.js';

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
    const uid = isAdmin ? userIdFilter : session.userId;
    const isAdminAll = isAdmin && !userIdFilter;
    if (!isAdminAll && !uid) return res.status(200).json([]);

    try {
      await ensureOrdersOptionalColumns(sql);
      let rows;
      try {
        if (isAdminAll) {
          rows = await sql`
          SELECT o.id, o.user_id, o.customer_name, o.customer_phone, o.customer_email, o.delivery_address, o.items,
                 o.subtotal, o.tax, o.total, o.fulfillment_type, o.scheduled_pickup_date, o.status,
                 o.stripe_payment_intent_id, o.manual_paid_at, o.created_at, o.updated_at, o.estimated_ready_time,
                 o.custom_cake_order_ids, o.ai_cake_design_ids, o.promo_code, o.tip_cents,
                 COALESCE(u.points, 0)::int AS user_points
          FROM orders o
          LEFT JOIN users u ON o.user_id = u.id
          ORDER BY o.created_at DESC NULLS LAST
          LIMIT 500
        `;
        } else {
          rows = await sql`
          SELECT o.id, o.user_id, o.customer_name, o.customer_phone, o.customer_email, o.delivery_address, o.items,
                 o.subtotal, o.tax, o.total, o.fulfillment_type, o.scheduled_pickup_date, o.status,
                 o.stripe_payment_intent_id, o.manual_paid_at, o.created_at, o.updated_at, o.estimated_ready_time,
                 o.custom_cake_order_ids, o.ai_cake_design_ids, o.promo_code, o.tip_cents,
                 COALESCE(u.points, 0)::int AS user_points
          FROM orders o
          LEFT JOIN users u ON o.user_id = u.id
          WHERE o.user_id::text = ${String(uid)}
          ORDER BY o.created_at DESC NULLS LAST
          LIMIT 200
        `;
        }
      } catch (selectErr) {
        if (selectErr?.code !== '42703') throw selectErr;
        console.warn('[orders] GET missing optional columns (42703), using legacy SELECT');
        if (isAdminAll) {
          rows = await sql`
          SELECT o.id, o.user_id, o.customer_name, o.customer_phone, o.customer_email, o.delivery_address, o.items,
                 o.subtotal, o.tax, o.total, o.fulfillment_type, o.scheduled_pickup_date, o.status,
                 o.stripe_payment_intent_id, o.manual_paid_at, o.created_at, o.updated_at, o.estimated_ready_time,
                 o.custom_cake_order_ids, o.ai_cake_design_ids,
                 COALESCE(u.points, 0)::int AS user_points
          FROM orders o
          LEFT JOIN users u ON o.user_id = u.id
          ORDER BY o.created_at DESC NULLS LAST
          LIMIT 500
        `;
        } else {
          rows = await sql`
          SELECT o.id, o.user_id, o.customer_name, o.customer_phone, o.customer_email, o.delivery_address, o.items,
                 o.subtotal, o.tax, o.total, o.fulfillment_type, o.scheduled_pickup_date, o.status,
                 o.stripe_payment_intent_id, o.manual_paid_at, o.created_at, o.updated_at, o.estimated_ready_time,
                 o.custom_cake_order_ids, o.ai_cake_design_ids,
                 COALESCE(u.points, 0)::int AS user_points
          FROM orders o
          LEFT JOIN users u ON o.user_id = u.id
          WHERE o.user_id::text = ${String(uid)}
          ORDER BY o.created_at DESC NULLS LAST
          LIMIT 200
        `;
        }
      }
      if (isAdminAll) {
        const statusQ = String(req.query?.status ?? '').trim();
        const fulfillmentQ = String(req.query?.fulfillmentType ?? req.query?.fulfillment_type ?? '').trim();
        const searchQ = String(req.query?.search ?? req.query?.q ?? '').trim().toLowerCase();
        const fromStr = String(req.query?.dateFrom ?? req.query?.date_from ?? '').trim();
        const toStr = String(req.query?.dateTo ?? req.query?.date_to ?? '').trim();
        const fromTs = fromStr ? Date.parse(fromStr) : NaN;
        const toTs = toStr ? Date.parse(toStr) : NaN;
        rows = (rows || []).filter((r) => {
          if (statusQ && String(r.status ?? '') !== statusQ) return false;
          if (fulfillmentQ && String(r.fulfillment_type ?? '') !== fulfillmentQ) return false;
          if (searchQ) {
            const hay = `${r.customer_name ?? ''} ${r.customer_phone ?? ''} ${r.customer_email ?? ''}`.toLowerCase();
            if (!hay.includes(searchQ)) return false;
          }
          if (Number.isFinite(fromTs)) {
            const t = r.created_at ? new Date(r.created_at).getTime() : 0;
            if (t < fromTs) return false;
          }
          if (Number.isFinite(toTs)) {
            const t = r.created_at ? new Date(r.created_at).getTime() : 0;
            if (t > toTs + 86400000 - 1) return false;
          }
          return true;
        });
      }
      return res.status(200).json((rows || []).map(rowToOrder));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[orders] GET', err?.code, err?.message, err);
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
    if (!checkRateLimit(req, 'orders_create', { max: 40, windowMs: 60_000 })) {
      return res.status(429).json({
        error: 'Too many orders from this network. Please wait a minute and try again.',
        details: [{ requestId }],
      });
    }
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
    const promoCodeRaw = String(body.promoCode ?? body.promo_code ?? '').trim();
    const promoCode = promoCodeRaw ? promoCodeRaw.toUpperCase() : '';

    let idemKey = String(req.headers?.['idempotency-key'] ?? req.headers?.['Idempotency-Key'] ?? body.idempotencyKey ?? body.idempotency_key ?? '').trim();
    if (idemKey.length > 200) idemKey = idemKey.slice(0, 200);

    const itemsJson = items.map((i) => ({
      id: i.id,
      productId: i.productId,
      name: i.name,
      price: Number(i.price ?? 0),
      quantity: Number(i.quantity ?? 0),
      specialInstructions: i.specialInstructions ?? '',
    }));

    try {
      await ensureOrdersOptionalColumns(sql);
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

      const materiallyDiscounted = discountedSubtotalCents < itemsSubtotalCents - 1;
      let expectedDiscountedCents = itemsSubtotalCents;
      if (materiallyDiscounted || promoCode) {
        if (materiallyDiscounted && !promoCode) {
          return res.status(400).json({
            error: 'Promo code is required when a discount is applied.',
            details: [{ requestId }],
          });
        }
        if (promoCode) {
          let promoRows;
          try {
            promoRows = await sql`
              SELECT discount_type, value, valid_from, valid_to, is_active,
                     min_subtotal, min_total_quantity, first_order_only
              FROM promotions
              WHERE UPPER(TRIM(code)) = ${promoCode}
              LIMIT 1
            `;
          } catch (pe) {
            if (pe?.code === '42P01') {
              return res.status(400).json({ error: 'Promotions are not available.', details: [{ requestId }] });
            }
            throw pe;
          }
          const pr = promoRows?.[0];
          const itemsSubtotalDollars = itemsSubtotalCents / 100;
          const totalQuantity = itemsJson.reduce((sum, i) => {
            const q = Math.trunc(Number(i?.quantity ?? 0));
            return sum + (q > 0 ? q : 0);
          }, 0);

          let priorOrderCount = 0;
          if (pr?.first_order_only) {
            if (!userId) {
              return res.status(400).json({
                error: 'Sign in with your account to use this first-order promo.',
                details: [{ requestId, code: 'SIGNIN_REQUIRED' }],
              });
            }
            try {
              const [rc] = await sql`
                SELECT COUNT(*)::int AS c FROM orders WHERE user_id::text = ${String(userId)}
              `;
              priorOrderCount = Number(rc?.c ?? 0);
            } catch (cntErr) {
              console.error('[orders] POST promo first-order count', cntErr);
              return res.status(400).json({
                error: 'Could not verify first-order eligibility. Please try again.',
                details: [{ requestId, code: 'ELIGIBILITY_UNKNOWN' }],
              });
            }
          }

          const promoEval = evaluatePromotion(pr, itemsSubtotalDollars, {
            totalQuantity,
            userId: userId || null,
            priorOrderCount,
          });
          if (!promoEval.ok) {
            return res.status(400).json({
              error: promoEval.message,
              details: [{ requestId, code: promoEval.code }],
            });
          }
          const discountDollars = promoEval.discountDollars;
          expectedDiscountedCents = Math.max(0, Math.round(itemsSubtotalCents - discountDollars * 100));
        }
        if (Math.abs(discountedSubtotalCents - expectedDiscountedCents) > 1) {
          return res.status(400).json({
            error: 'Order total does not match this promo. Please refresh and try again.',
            details: [{ requestId }],
          });
        }
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

      async function fetchOrderRowById(orderId) {
        const [r] = await sql`
          SELECT id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
                 subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status,
                 stripe_payment_intent_id, manual_paid_at, created_at, updated_at, estimated_ready_time,
                 custom_cake_order_ids, ai_cake_design_ids, promo_code, tip_cents
          FROM orders WHERE id = ${orderId} LIMIT 1
        `;
        return r;
      }

      async function returnExistingOrder(orderIdStr) {
        const row = await fetchOrderRowById(orderIdStr);
        if (!row) return res.status(500).json({ error: 'Failed to load order', details: [{ requestId }] });
        const order = rowToOrder(row);
        return res.status(201).json({ id: order.id, subtotal: order.subtotal, tax: order.tax, total: order.total });
      }

      if (idemKey) {
        try {
          const existing = await sql`
            SELECT order_id FROM order_idempotency WHERE idempotency_key = ${idemKey} LIMIT 1
          `;
          const oid = existing?.[0]?.order_id;
          if (oid) {
            return returnExistingOrder(String(oid));
          }

          const claimed = await sql`
            INSERT INTO order_idempotency (idempotency_key) VALUES (${idemKey})
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING idempotency_key
          `;
          if (!claimed?.length) {
            for (let i = 0; i < 25; i += 1) {
              await new Promise((r) => setTimeout(r, 120));
              const again = await sql`
                SELECT order_id FROM order_idempotency WHERE idempotency_key = ${idemKey} LIMIT 1
              `;
              const o2 = again?.[0]?.order_id;
              if (o2) return returnExistingOrder(String(o2));
            }
            return res.status(409).json({
              error: 'Duplicate order request is still processing. Please wait and check your orders.',
              details: [{ requestId }],
            });
          }
        } catch (idemErr) {
          if (idemErr?.code !== '42P01') throw idemErr;
        }
      }

      const tipCentsVal = totals?.tipCentsInferred ?? 0;
      const promoCodeVal = promoCode && promoCode.length > 0 ? promoCode : null;

      const [row] = await sql`
        INSERT INTO orders (user_id, customer_name, customer_phone, customer_email, delivery_address, items,
          subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status, stripe_payment_intent_id,
          estimated_ready_time, custom_cake_order_ids, ai_cake_design_ids, promo_code, tip_cents)
        VALUES (${userId}, ${customerName}, ${customerPhone}, ${customerEmail ?? null}, ${deliveryAddressClean}, ${JSON.stringify(itemsJson)},
          ${computed.subtotal}, ${computed.tax}, ${computed.total}, ${normalizedFulfillmentType}, ${scheduledPickupDate ? new Date(scheduledPickupDate) : null}, ${status}, ${stripePaymentIntentId ?? null},
          ${estimatedReadyTime ? new Date(estimatedReadyTime) : null}, ${customCakeOrderIds}, ${aiCakeDesignIds}, ${promoCodeVal}, ${tipCentsVal})
        RETURNING id, user_id, customer_name, customer_phone, customer_email, delivery_address, items,
          subtotal, tax, total, fulfillment_type, scheduled_pickup_date, status, stripe_payment_intent_id,
          manual_paid_at, created_at, updated_at, estimated_ready_time, custom_cake_order_ids, ai_cake_design_ids, promo_code, tip_cents
      `;
      const order = rowToOrder(row);
      if (idemKey) {
        try {
          await sql`
            UPDATE order_idempotency SET order_id = ${order.id}
            WHERE idempotency_key = ${idemKey}
          `;
        } catch (e) {
          if (e?.code !== '42P01') console.warn('[orders] idempotency update', e?.message ?? e);
        }
      }
      return res.status(201).json({ id: order.id, subtotal: order.subtotal, tax: order.tax, total: order.total });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[orders] POST', { requestId, err });
      return res.status(500).json({ error: 'Failed to create order', details: [{ requestId }] });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
