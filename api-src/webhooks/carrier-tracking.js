/**
 * POST /api/webhooks/carrier-tracking
 * Updates parcel tracking on an order (UPS / FedEx / USPS). No user session — verify shared secret.
 *
 * Headers: `X-Carrier-Tracking-Secret: <same as CARRIER_TRACKING_WEBHOOK_SECRET>`
 *   or `Authorization: Bearer <secret>`
 *
 * Body JSON: { "orderId": "<uuid>", "trackingCarrier"?: "ups"|"fedex"|"usps",
 *              "trackingNumber"?: string, "trackingStatusDetail"?: string }
 *
 * Shipping orders: if trackingStatusDetail looks like a final delivery (e.g. contains "Delivered"),
 * status is set to Completed and loyalty + customer push run (same as manual complete).
 * Response includes `orderCompleted: true` when that happened.
 */
import crypto from 'crypto';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { ensureOrdersOptionalColumns } from '../lib/ordersSchema.js';
import { parcelTrackingFieldsFromRow } from '../../api/lib/parcelTrackingUrls.js';
import { completeShippingOrderIfTrackingDelivered } from '../../api/lib/completeOrderIfTrackingDelivered.js';
import { hasValidParcelTracking, isShippingFulfillmentType } from '../../api/lib/shippingReadyTrackingRule.js';

function timingSafeEqualStrings(a, b) {
  const x = Buffer.from(String(a ?? ''), 'utf8');
  const y = Buffer.from(String(b ?? ''), 'utf8');
  if (x.length !== y.length) return false;
  return crypto.timingSafeEqual(x, y);
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  if ((req.method || '').toUpperCase() !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const expected = (process.env.CARRIER_TRACKING_WEBHOOK_SECRET || '').trim();
  if (!expected) {
    console.warn('[webhooks/carrier-tracking] CARRIER_TRACKING_WEBHOOK_SECRET not set');
    return res.status(503).json({ error: 'Webhook not configured' });
  }

  const authHdr = (req.headers?.authorization || '').toString();
  const bearer = authHdr.replace(/^Bearer\s+/i, '').trim();
  const headerSecret =
    (req.headers?.['x-carrier-tracking-secret'] || req.headers?.['X-Carrier-Tracking-Secret'] || '')
      .toString()
      .trim() || bearer;

  if (!timingSafeEqualStrings(headerSecret, expected)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  const body = req.body || {};
  const orderId = String(body.orderId ?? body.order_id ?? '').trim();
  if (!orderId) return res.status(400).json({ error: 'orderId is required' });

  try {
    await ensureOrdersOptionalColumns(sql);
  } catch (e) {
    console.warn('[webhooks/carrier-tracking] ensureOrdersOptionalColumns', e?.message ?? e);
  }

  const hasCarrier = 'trackingCarrier' in body || 'tracking_carrier' in body;
  const hasNumber = 'trackingNumber' in body || 'tracking_number' in body;
  const hasDetail = 'trackingStatusDetail' in body || 'tracking_status_detail' in body;
  if (!hasCarrier && !hasNumber && !hasDetail) {
    return res.status(400).json({ error: 'No tracking fields provided' });
  }

  try {
    const [cur] = await sql`
      SELECT tracking_carrier, tracking_number, tracking_status_detail, fulfillment_type, user_id
      FROM orders WHERE id = ${orderId}
    `;
    if (!cur) return res.status(404).json({ error: 'Order not found' });

    const hadValidTrackingBefore = hasValidParcelTracking(cur.tracking_carrier, cur.tracking_number);

    let carrier = cur.tracking_carrier ?? null;
    let number = cur.tracking_number ?? null;
    let detail = cur.tracking_status_detail ?? null;

    if (hasCarrier) {
      const v = body.trackingCarrier ?? body.tracking_carrier;
      carrier = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim().toLowerCase();
    }
    if (hasNumber) {
      const v = body.trackingNumber ?? body.tracking_number;
      number = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim();
    }
    if (hasDetail) {
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
      WHERE id = ${orderId}
    `;

    const shouldStampParcelLabeledAt =
      isShippingFulfillmentType(cur.fulfillment_type) &&
      !hadValidTrackingBefore &&
      hasValidParcelTracking(carrier, number);
    if (shouldStampParcelLabeledAt) {
      try {
        await sql`
          UPDATE orders SET parcel_labeled_at = COALESCE(parcel_labeled_at, NOW())
          WHERE id = ${orderId}
        `;
      } catch (stampErr) {
        console.warn('[webhooks/carrier-tracking] parcel_labeled_at', stampErr?.message ?? stampErr);
      }
    }

    let orderAutoCompleted = false;
    try {
      const r = await completeShippingOrderIfTrackingDelivered(sql, orderId, detail);
      orderAutoCompleted = r.completed === true;
    } catch (e) {
      console.warn('[webhooks/carrier-tracking] auto-complete', e?.message ?? e);
    }

    try {
      const { notifyCustomerTrackingNumberAvailable } = await import('../../api/lib/apns.js');
      await notifyCustomerTrackingNumberAvailable(
        sql,
        orderId,
        cur.user_id,
        cur.fulfillment_type,
        hadValidTrackingBefore,
        carrier,
        number
      );
    } catch (pushErr) {
      console.warn('[webhooks/carrier-tracking] tracking available push', pushErr?.message ?? pushErr);
    }

    const [row] = await sql`
      SELECT id, tracking_carrier, tracking_number, tracking_status_detail, tracking_updated_at, parcel_labeled_at
      FROM orders WHERE id = ${orderId}
    `;
    const fields = parcelTrackingFieldsFromRow(row || {});
    return res.status(200).json({ ok: true, orderId, orderCompleted: orderAutoCompleted, ...fields });
  } catch (err) {
    if (err?.code === '42703') {
      return res.status(503).json({ error: 'Database missing tracking columns; run migrations' });
    }
    console.error('[webhooks/carrier-tracking]', err);
    return res.status(500).json({ error: 'Failed to update tracking' });
  }
}
