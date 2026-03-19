/**
 * GET/PATCH /api/settings/business — full business settings (store, delivery, tax, fees).
 * GET: returns settings for app (including deliveryFee, shippingFee). Public GET for checkout; PATCH requires admin.
 * PATCH body: same shape; updates business_settings key 'main'.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

const DEFAULT_MAIN = {
  lead_time_hours: 24,
  business_hours: { mon: '9-17', tue: '9-17', wed: '9-17', thu: '9-17', fri: '9-17', sat: '9-15', sun: null },
  min_order_cents: 0,
  tax_rate_percent: 8,
  store_hours: null,
  store_name: null,
  delivery_radius_miles: null,
  contact_email: null,
  contact_phone: null,
  cash_app_tag: null,
  venmo_username: null,
  delivery_fee: null,
  shipping_fee: null,
};

function toAppResponse(row) {
  const v = row?.value_json ? { ...DEFAULT_MAIN, ...row.value_json } : DEFAULT_MAIN;
  const taxRate = (v.tax_rate_percent != null ? Number(v.tax_rate_percent) / 100 : 0.08);
  return {
    storeHours: v.store_hours ?? null,
    deliveryRadiusMiles: v.delivery_radius_miles != null ? Number(v.delivery_radius_miles) : null,
    taxRate,
    minimumOrderLeadTimeHours: v.lead_time_hours != null ? Number(v.lead_time_hours) : null,
    contactEmail: v.contact_email ?? null,
    contactPhone: v.contact_phone ?? null,
    storeName: v.store_name ?? null,
    cashAppTag: v.cash_app_tag ?? null,
    venmoUsername: v.venmo_username ?? null,
    deliveryFee: v.delivery_fee != null ? Number(v.delivery_fee) : null,
    shippingFee: v.shipping_fee != null ? Number(v.shipping_fee) : null,
  };
}

function toDbValue(body) {
  const leadTime = body.minimumOrderLeadTimeHours != null ? Number(body.minimumOrderLeadTimeHours) : undefined;
  const taxPercent = body.taxRate != null ? Math.round(Number(body.taxRate) * 100) : undefined;
  return {
    store_hours: body.storeHours != null ? String(body.storeHours) : undefined,
    store_name: body.storeName != null ? String(body.storeName) : undefined,
    delivery_radius_miles: body.deliveryRadiusMiles != null ? Number(body.deliveryRadiusMiles) : undefined,
    contact_email: body.contactEmail != null ? String(body.contactEmail) : undefined,
    contact_phone: body.contactPhone != null ? String(body.contactPhone) : undefined,
    cash_app_tag: body.cashAppTag != null ? String(body.cashAppTag) : undefined,
    venmo_username: body.venmoUsername != null ? String(body.venmoUsername) : undefined,
    delivery_fee: body.deliveryFee != null ? Number(body.deliveryFee) : undefined,
    shipping_fee: body.shippingFee != null ? Number(body.shippingFee) : undefined,
    lead_time_hours: leadTime,
    tax_rate_percent: taxPercent,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if ((req.method || '').toUpperCase() !== 'GET' && (req.method || '').toUpperCase() !== 'PATCH') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) {
      return res.status(403).json({ error: 'Admin required' });
    }
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Service unavailable' });
  }

  try {
    if ((req.method || '').toUpperCase() === 'GET') {
      const [row] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
      return res.status(200).json(toAppResponse(row));
    }

    const body = typeof req.body === 'object' ? req.body : {};
    const [existing] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
    const current = existing?.value_json ? { ...DEFAULT_MAIN, ...existing.value_json } : { ...DEFAULT_MAIN };
    const updates = toDbValue(body);
    const next = { ...current };
    for (const [k, v] of Object.entries(updates)) {
      if (v !== undefined) next[k] = v;
    }
    await sql`
      INSERT INTO business_settings (key, value_json, updated_at)
      VALUES ('main', ${JSON.stringify(next)}::jsonb, NOW())
      ON CONFLICT (key) DO UPDATE SET value_json = ${JSON.stringify(next)}::jsonb, updated_at = NOW()
    `;
    const [updated] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
    return res.status(200).json(toAppResponse(updated));
  } catch (e) {
    console.error('[settings/business]', e);
    return res.status(500).json({ error: 'Server error' });
  }
}
