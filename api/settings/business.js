/**
 * GET/PATCH /api/settings/business — full business settings (store, delivery, tax, fees).
 * GET: returns settings for app (including deliveryFee, shippingFee). Public GET for checkout; PATCH requires admin.
 * PATCH body: same shape; updates business_settings key 'main'.
 * Stripe: stripePublishableKey (pk_live_… / pk_test_…) is returned on GET for the app.
 * stripe_secret_key is stored in DB but never returned; use stripeSecretKeyConfigured to see if server can charge.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getStripeSecretKey } from '../../api/lib/stripeSecret.js';

/** Display name for audit: session displayName, else email. */
function saverDisplayNameFromSession(session) {
  if (!session) return null;
  const d = session.displayName != null ? String(session.displayName).trim() : '';
  if (d) return d;
  const e = session.email != null ? String(session.email).trim() : '';
  return e || null;
}

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

async function buildAppResponse(row, sql) {
  const v = row?.value_json ? { ...DEFAULT_MAIN, ...row.value_json } : DEFAULT_MAIN;
  const taxRate = (v.tax_rate_percent != null ? Number(v.tax_rate_percent) / 100 : 0.08);
  const updatedByUserId =
    v.settings_last_updated_by_user_id != null ? String(v.settings_last_updated_by_user_id) : null;
  const colName =
    row?.settings_last_updated_by_name != null ? String(row.settings_last_updated_by_name).trim() : '';
  const jsonName =
    v.settings_last_updated_by_name != null ? String(v.settings_last_updated_by_name).trim() : '';
  let updatedByName = colName || jsonName || null;
  if (updatedByUserId && !updatedByName) {
    try {
      const [userRow] = await sql`
        SELECT display_name, email
        FROM users
        WHERE id::text = ${updatedByUserId}
        LIMIT 1
      `;
      const display = userRow?.display_name != null ? String(userRow.display_name).trim() : '';
      if (display) {
        updatedByName = display;
      } else if (userRow?.email != null) {
        const email = String(userRow.email).trim();
        updatedByName = email || null;
      }
    } catch {
      updatedByName = null;
    }
  }
  const pk =
    v.stripe_publishable_key != null && String(v.stripe_publishable_key).trim() !== ''
      ? String(v.stripe_publishable_key).trim()
      : null;
  const secretConfigured = !!(await getStripeSecretKey(sql));
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
    settingsLastUpdatedAt: v.settings_last_updated_at ?? null,
    settingsLastUpdatedByUserId: updatedByUserId,
    settingsLastUpdatedByName: updatedByName,
    stripePublishableKey: pk,
    /** True if STRIPE_SECRET_KEY env or DB secret is set (PaymentIntents can be created). */
    stripeCheckoutEnabled: secretConfigured,
    /** True if a secret key is configured (env or DB); secret value is never returned. */
    stripeSecretKeyConfigured: secretConfigured,
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

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Service unavailable' });
  }

  try {
    if ((req.method || '').toUpperCase() === 'GET') {
      const [row] = await sql`
        SELECT value_json, settings_last_updated_by_name
        FROM business_settings
        WHERE key = 'main'
        LIMIT 1
      `;
      return res.status(200).json(await buildAppResponse(row, sql));
    }

    const patchToken = getTokenFromRequest(req);
    const session = patchToken ? await getSession(patchToken) : null;
    if (!session?.userId || session.isAdmin !== true) {
      return res.status(403).json({ error: 'Admin required' });
    }

    const body = typeof req.body === 'object' ? req.body : {};
    const [existing] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
    const current = existing?.value_json ? { ...DEFAULT_MAIN, ...existing.value_json } : { ...DEFAULT_MAIN };
    const updates = toDbValue(body);
    const next = { ...current };
    for (const [k, v] of Object.entries(updates)) {
      if (v !== undefined) next[k] = v;
    }
    next.settings_last_updated_at = new Date().toISOString();
    next.settings_last_updated_by_user_id = session?.userId != null ? String(session.userId) : null;
    const saverName = saverDisplayNameFromSession(session);
    next.settings_last_updated_by_name = saverName;
    const legacyTaxRate = next.tax_rate_percent != null ? Number(next.tax_rate_percent) / 100 : 0.08;
    await sql`
      INSERT INTO business_settings (
        key,
        value_json,
        store_hours,
        store_name,
        delivery_radius_miles,
        tax_rate,
        contact_email,
        contact_phone,
        cash_app_tag,
        venmo_username,
        settings_last_updated_by_name,
        updated_at
      )
      VALUES (
        'main',
        ${JSON.stringify(next)}::jsonb,
        ${next.store_hours ?? null},
        ${next.store_name ?? null},
        ${next.delivery_radius_miles ?? null},
        ${legacyTaxRate},
        ${next.contact_email ?? null},
        ${next.contact_phone ?? null},
        ${next.cash_app_tag ?? null},
        ${next.venmo_username ?? null},
        ${saverName},
        NOW()
      )
      ON CONFLICT (key) DO UPDATE SET
        value_json = ${JSON.stringify(next)}::jsonb,
        store_hours = ${next.store_hours ?? null},
        store_name = ${next.store_name ?? null},
        delivery_radius_miles = ${next.delivery_radius_miles ?? null},
        tax_rate = ${legacyTaxRate},
        contact_email = ${next.contact_email ?? null},
        contact_phone = ${next.contact_phone ?? null},
        cash_app_tag = ${next.cash_app_tag ?? null},
        venmo_username = ${next.venmo_username ?? null},
        settings_last_updated_by_name = ${saverName},
        updated_at = NOW()
    `;
    const [updated] = await sql`
      SELECT value_json, settings_last_updated_by_name
      FROM business_settings
      WHERE key = 'main'
      LIMIT 1
    `;
    return res.status(200).json(await buildAppResponse(updated, sql));
  } catch (e) {
    console.error('[settings/business]', e);
    return res.status(500).json({ error: 'Server error' });
  }
}
