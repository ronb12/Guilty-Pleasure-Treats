import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToSettings(row) {
  if (!row) return null;
  return {
    storeHours: row.store_hours ?? null,
    deliveryRadiusMiles: row.delivery_radius_miles != null ? Number(row.delivery_radius_miles) : null,
    taxRate: Number(row.tax_rate ?? 0.08),
    minimumOrderLeadTimeHours: row.minimum_order_lead_time_hours != null ? Number(row.minimum_order_lead_time_hours) : null,
    contactEmail: row.contact_email ?? null,
    contactPhone: row.contact_phone ?? null,
    storeName: row.store_name ?? null,
    cashAppTag: row.cash_app_tag ?? null,
    venmoUsername: row.venmo_username ?? null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    const rows = await sql`SELECT * FROM business_settings WHERE id = 'business' LIMIT 1`;
    const settings = rowToSettings(rows[0]);
    return res.status(200).json(settings || { taxRate: 0.08, minimumOrderLeadTimeHours: 24 });
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const storeHours = body.storeHours != null ? String(body.storeHours) : null;
    const deliveryRadiusMiles = body.deliveryRadiusMiles != null ? Number(body.deliveryRadiusMiles) : null;
    const taxRate = body.taxRate != null ? Number(body.taxRate) : 0.08;
    const minimumOrderLeadTimeHours = body.minimumOrderLeadTimeHours != null ? Number(body.minimumOrderLeadTimeHours) : null;
    const contactEmail = body.contactEmail != null ? String(body.contactEmail) : null;
    const contactPhone = body.contactPhone != null ? String(body.contactPhone) : null;
    const storeName = body.storeName != null ? String(body.storeName) : null;
    const cashAppTag = body.cashAppTag != null ? String(body.cashAppTag) : null;
    const venmoUsername = body.venmoUsername != null ? String(body.venmoUsername) : null;

    await sql`
      INSERT INTO business_settings (id, store_hours, delivery_radius_miles, tax_rate, minimum_order_lead_time_hours, contact_email, contact_phone, store_name, cash_app_tag, venmo_username, updated_at)
      VALUES ('business', ${storeHours}, ${deliveryRadiusMiles}, ${taxRate}, ${minimumOrderLeadTimeHours}, ${contactEmail}, ${contactPhone}, ${storeName}, ${cashAppTag}, ${venmoUsername}, NOW())
      ON CONFLICT (id) DO UPDATE SET
        store_hours = COALESCE(EXCLUDED.store_hours, business_settings.store_hours),
        delivery_radius_miles = COALESCE(EXCLUDED.delivery_radius_miles, business_settings.delivery_radius_miles),
        tax_rate = COALESCE(EXCLUDED.tax_rate, business_settings.tax_rate),
        minimum_order_lead_time_hours = COALESCE(EXCLUDED.minimum_order_lead_time_hours, business_settings.minimum_order_lead_time_hours),
        contact_email = COALESCE(EXCLUDED.contact_email, business_settings.contact_email),
        contact_phone = COALESCE(EXCLUDED.contact_phone, business_settings.contact_phone),
        store_name = COALESCE(EXCLUDED.store_name, business_settings.store_name),
        cash_app_tag = COALESCE(EXCLUDED.cash_app_tag, business_settings.cash_app_tag),
        venmo_username = COALESCE(EXCLUDED.venmo_username, business_settings.venmo_username),
        updated_at = NOW()
    `;
    const rows = await sql`SELECT * FROM business_settings WHERE id = 'business' LIMIT 1`;
    return res.status(200).json(rowToSettings(rows[0]));
  }

  res.status(405).json({ error: 'Method not allowed' });
}
