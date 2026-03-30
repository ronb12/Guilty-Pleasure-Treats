/**
 * GET /api/custom-cake-options - list sizes, flavors, frostings, toppings (from business_settings or default).
 */
import { sql, hasDb } from '../lib/db.js';
import { setCors, handleOptions } from '../lib/cors.js';

const DEFAULT_OPTIONS = {
  sizes: [],
  flavors: [],
  frostings: [],
  toppings: [],
  colors: [],
  fillings: [],
};

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(200).json(DEFAULT_OPTIONS);
  }
  try {
    const rows = await sql`
      SELECT value_json FROM business_settings WHERE key = 'custom_cake_options' LIMIT 1
    `;
    if (!rows.length || !rows[0].value_json) {
      return res.status(200).json(DEFAULT_OPTIONS);
    }
    const raw = rows[0].value_json;
    const options = typeof raw === 'object' ? raw : (typeof raw === 'string' ? JSON.parse(raw) : DEFAULT_OPTIONS);
    const response = {
      sizes: Array.isArray(options.sizes) ? options.sizes : DEFAULT_OPTIONS.sizes,
      flavors: Array.isArray(options.flavors) ? options.flavors : DEFAULT_OPTIONS.flavors,
      frostings: Array.isArray(options.frostings) ? options.frostings : DEFAULT_OPTIONS.frostings,
      toppings: Array.isArray(options.toppings) ? options.toppings : DEFAULT_OPTIONS.toppings,
      colors: Array.isArray(options.colors) ? options.colors : DEFAULT_OPTIONS.colors,
      fillings: Array.isArray(options.fillings) ? options.fillings : DEFAULT_OPTIONS.fillings,
    };
    return res.status(200).json(response);
  } catch (err) {
    if (err?.code === '42P01') return res.status(200).json(DEFAULT_OPTIONS);
    console.error('[custom-cake-options] GET', err);
    return res.status(200).json(DEFAULT_OPTIONS);
  }
}
