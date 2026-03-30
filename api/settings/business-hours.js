/**
 * GET/PUT /api/settings/business-hours — business hours and lead time (admin).
 * GET: returns { lead_time_hours, business_hours, min_order_cents, tax_rate_percent }.
 * PUT body: { lead_time_hours?, business_hours?, min_order_cents?, tax_rate_percent? }
 */
const { withCors } = require('../../api/lib/cors');
const { getAuth } = require('../../api/lib/auth');
const { sql } = require('../../api/lib/db');

const DEFAULT = {
  lead_time_hours: 24,
  business_hours: { mon: '9-17', tue: '9-17', wed: '9-17', thu: '9-17', fri: '9-17', sat: '9-15', sun: null },
  min_order_cents: 0,
  tax_rate_percent: 0
};

async function handler(req, res) {
  if (req.method === 'OPTIONS') return withCors(req, res, () => res.status(204).end());
  if (req.method !== 'GET' && req.method !== 'PUT') return res.status(405).json({ error: 'Method not allowed' });

  const auth = await getAuth(req);
  if (!auth?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (req.method === 'PUT' && auth.isAdmin !== true) return res.status(403).json({ error: 'Admin only' });

  try {
    if (req.method === 'GET') {
      const [row] = await sql`SELECT value_json FROM business_settings WHERE key = 'main'`;
      const value = row?.value_json ? { ...DEFAULT, ...row.value_json } : DEFAULT;
      return res.status(200).json(value);
    }
    let body;
    try {
      body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    } catch {
      return res.status(400).json({ error: 'Invalid JSON' });
    }
    const [existing] = await sql`SELECT value_json FROM business_settings WHERE key = 'main'`;
    const current = existing?.value_json ? { ...DEFAULT, ...existing.value_json } : DEFAULT;
    const next = {
      lead_time_hours: body.lead_time_hours ?? current.lead_time_hours,
      business_hours: body.business_hours ?? current.business_hours,
      min_order_cents: body.min_order_cents ?? current.min_order_cents,
      tax_rate_percent: body.tax_rate_percent ?? current.tax_rate_percent
    };
    await sql`
      INSERT INTO business_settings (key, value_json, updated_at)
      VALUES ('main', ${JSON.stringify(next)}::jsonb, NOW())
      ON CONFLICT (key) DO UPDATE SET value_json = ${JSON.stringify(next)}::jsonb, updated_at = NOW()
    `;
    return res.status(200).json(next);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = handler;
