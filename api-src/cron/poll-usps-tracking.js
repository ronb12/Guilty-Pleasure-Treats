/**
 * GET or POST /api/cron/poll-usps-tracking
 * Authorization: Bearer <PARCEL_TRACKING_POLL_SECRET or CRON_SECRET> (same pattern as Vercel Cron).
 *
 * For **Shipping** orders with **tracking_carrier = usps** and a tracking number: calls
 * USPS Tracking API (free developer credentials), updates `tracking_status_detail`, then
 * runs `completeShippingOrderIfTrackingDelivered` when the summary looks delivered.
 *
 * Env:
 *   USPS_CLIENT_ID, USPS_CLIENT_SECRET — from USPS COP / developer app (Consumer Key & Secret)
 *   USPS_API_BASE — optional, default https://apis.usps.com (use https://apis-tem.usps.com for TEM)
 */
import crypto from 'crypto';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { ensureOrdersOptionalColumns } from '../lib/ordersSchema.js';
import { fetchUspsTrackingSummaryText } from '../../api/lib/uspsTrackingApi.js';
import { completeShippingOrderIfTrackingDelivered } from '../../api/lib/completeOrderIfTrackingDelivered.js';

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
  const method = (req.method || '').toUpperCase();
  if (method !== 'GET' && method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authHdr = (req.headers?.authorization || '').toString();
  const bearer = authHdr.replace(/^Bearer\s+/i, '').trim();
  const secrets = [process.env.PARCEL_TRACKING_POLL_SECRET, process.env.CRON_SECRET]
    .map((s) => String(s ?? '').trim())
    .filter(Boolean);
  const authorized = secrets.some((s) => timingSafeEqualStrings(bearer, s));
  if (!secrets.length || !authorized) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const clientId = (process.env.USPS_CLIENT_ID || '').trim();
  const clientSecret = (process.env.USPS_CLIENT_SECRET || '').trim();
  const baseUrl = (process.env.USPS_API_BASE || 'https://apis.usps.com').trim();

  if (!clientId || !clientSecret) {
    return res.status(200).json({
      ok: true,
      enabled: false,
      message:
        'Set USPS_CLIENT_ID and USPS_CLIENT_SECRET (USPS Developer Portal → app Consumer Key & Secret). See https://developers.usps.com/getting-started',
      ordersConsidered: 0,
      trackingRowsUpdated: 0,
      ordersCompletedByTracking: 0,
    });
  }

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  try {
    await ensureOrdersOptionalColumns(sql);
  } catch (e) {
    console.warn('[cron/poll-usps-tracking] ensureOrdersOptionalColumns', e?.message ?? e);
  }

  let list;
  try {
    list = await sql`
      SELECT id, tracking_carrier, tracking_number, tracking_status_detail
      FROM orders
      WHERE LOWER(TRIM(COALESCE(fulfillment_type, ''))) = 'shipping'
        AND LOWER(TRIM(COALESCE(status, ''))) NOT IN ('completed', 'cancelled')
        AND tracking_number IS NOT NULL AND TRIM(tracking_number) != ''
        AND LOWER(TRIM(tracking_carrier)) = 'usps'
    `;
  } catch (err) {
    console.error('[cron/poll-usps-tracking] query', err);
    return res.status(500).json({ error: 'Database error' });
  }

  const rows = list || [];
  if (!rows.length) {
    return res.status(200).json({
      ok: true,
      enabled: true,
      ordersConsidered: 0,
      trackingRowsUpdated: 0,
      ordersCompletedByTracking: 0,
    });
  }

  let trackingRowsUpdated = 0;
  let ordersCompletedByTracking = 0;
  const errors = [];

  for (const row of rows) {
    const num = String(row.tracking_number).trim();
    let newText = '';
    try {
      newText = (
        await fetchUspsTrackingSummaryText({
          clientId,
          clientSecret,
          baseUrl,
          trackingNumber: num,
        })
      ).trim();
    } catch (e) {
      errors.push({ orderId: row.id, trackingNumber: num, error: String(e?.message ?? e) });
      console.warn('[cron/poll-usps-tracking] USPS', row.id, e?.message ?? e);
      await sleep(350);
      continue;
    }

    await sleep(350);

    if (!newText) continue;

    const oldText = String(row.tracking_status_detail ?? '').trim();
    if (oldText !== newText) {
      try {
        await sql`
          UPDATE orders SET
            tracking_status_detail = ${newText},
            tracking_updated_at = NOW(),
            updated_at = NOW()
          WHERE id = ${row.id}
        `;
        trackingRowsUpdated++;
      } catch (e) {
        console.error('[cron/poll-usps-tracking] update', row.id, e?.message ?? e);
        continue;
      }
    }

    try {
      const r = await completeShippingOrderIfTrackingDelivered(sql, row.id, newText);
      if (r.completed) ordersCompletedByTracking++;
    } catch (e) {
      console.warn('[cron/poll-usps-tracking] auto-complete', row.id, e?.message ?? e);
    }
  }

  return res.status(200).json({
    ok: true,
    enabled: true,
    carrier: 'usps',
    ordersConsidered: rows.length,
    trackingRowsUpdated,
    ordersCompletedByTracking,
    errors: errors.length ? errors : undefined,
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
