/**
 * GET /api/settings/custom-cake-options - same as public (sizes, flavors, frostings, toppings from business_settings).
 * PATCH /api/settings/custom-cake-options - admin: replace options. Body: { sizes, flavors, frostings, toppings, colors?, fillings? }.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

const DEFAULT_OPTIONS = { sizes: [], flavors: [], frostings: [], toppings: [], colors: [], fillings: [] };

function getOptionsFromRow(row) {
  if (!row?.value_json) return DEFAULT_OPTIONS;
  const raw = row.value_json;
  const o = typeof raw === 'object' ? raw : (typeof raw === 'string' ? JSON.parse(raw) : DEFAULT_OPTIONS);
  return {
    sizes: Array.isArray(o.sizes) ? o.sizes : DEFAULT_OPTIONS.sizes,
    flavors: Array.isArray(o.flavors) ? o.flavors : DEFAULT_OPTIONS.flavors,
    frostings: Array.isArray(o.frostings) ? o.frostings : DEFAULT_OPTIONS.frostings,
    toppings: Array.isArray(o.toppings) ? o.toppings : DEFAULT_OPTIONS.toppings,
    colors: Array.isArray(o.colors) ? o.colors : DEFAULT_OPTIONS.colors,
    fillings: Array.isArray(o.fillings) ? o.fillings : DEFAULT_OPTIONS.fillings,
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
    if (!hasDb() || !sql) return res.status(200).json(DEFAULT_OPTIONS);
    try {
      const rows = await sql`SELECT value_json FROM business_settings WHERE key = 'custom_cake_options' LIMIT 1`;
      const options = rows.length ? getOptionsFromRow(rows[0]) : DEFAULT_OPTIONS;
      return res.status(200).json(options);
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json(DEFAULT_OPTIONS);
      console.error('[settings/custom-cake-options] GET', err);
      return res.status(200).json(DEFAULT_OPTIONS);
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });
    const body = req.body || {};
    const sizes = Array.isArray(body.sizes) ? body.sizes : [];
    const flavors = Array.isArray(body.flavors) ? body.flavors : [];
    const frostings = Array.isArray(body.frostings) ? body.frostings : [];
    const toppings = Array.isArray(body.toppings) ? body.toppings : [];
    const colors = Array.isArray(body.colors) ? body.colors : [];
    const fillings = Array.isArray(body.fillings) ? body.fillings : [];
    const valueJson = JSON.stringify({ sizes, flavors, frostings, toppings, colors, fillings });
    try {
      await sql`
        INSERT INTO business_settings (key, value_json, updated_at)
        VALUES ('custom_cake_options', ${valueJson}::jsonb, NOW())
        ON CONFLICT (key) DO UPDATE SET value_json = ${valueJson}::jsonb, updated_at = NOW()
      `;
      return res.status(200).json({ sizes, flavors, frostings, toppings, colors, fillings });
    } catch (err) {
      console.error('[settings/custom-cake-options] PATCH', err);
      return res.status(500).json({ error: 'Failed to save cake options' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
