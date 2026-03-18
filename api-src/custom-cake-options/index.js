/**
 * GET /api/custom-cake-options
 * Public: returns sizes, flavors, frostings for the customer Custom Cake Builder.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToSize(row) {
  if (!row) return null;
  return { id: row.id, label: row.label, price: Number(row.price), sortOrder: row.sort_order ?? 0 };
}

function rowToOption(row) {
  if (!row) return null;
  return { id: row.id, label: row.label, sortOrder: row.sort_order ?? 0 };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const [sizesRows, flavorsRows, frostingsRows] = await Promise.all([
    sql`SELECT id, label, price, sort_order FROM cake_sizes ORDER BY sort_order ASC, label ASC`,
    sql`SELECT id, label, sort_order FROM cake_flavors ORDER BY sort_order ASC, label ASC`,
    sql`SELECT id, label, sort_order FROM frosting_types ORDER BY sort_order ASC, label ASC`,
  ]);
  let toppingsRows = [];
  try {
    toppingsRows = await sql`SELECT id, label, sort_order FROM cake_toppings ORDER BY sort_order ASC, label ASC`;
  } catch {
    // cake_toppings table may not exist until migration is run
  }

  const sizes = (sizesRows || []).map(rowToSize).filter(Boolean);
  const flavors = (flavorsRows || []).map(rowToOption).filter(Boolean);
  const frostings = (frostingsRows || []).map(rowToOption).filter(Boolean);
  const toppings = (toppingsRows || []).map(rowToOption).filter(Boolean);

  return res.status(200).json({ sizes, flavors, frostings, toppings });
}
