/**
 * GET /api/settings/custom-cake-options — admin: same as public options
 * PATCH /api/settings/custom-cake-options — admin: replace all sizes, flavors, frostings
 * Body: { sizes: [{ id?, label, price }], flavors: [{ id?, label }], frostings: [{ id?, label }] }
 * Sent arrays replace existing; omit id for new rows.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToSize(row) {
  if (!row) return null;
  return { id: row.id, label: row.label, price: Number(row.price), sortOrder: row.sort_order ?? 0 };
}

function rowToOption(row) {
  if (!row) return null;
  return { id: row.id, label: row.label, sortOrder: row.sort_order ?? 0 };
}

async function getOptions() {
  const [sizesRows, flavorsRows, frostingsRows] = await Promise.all([
    sql`SELECT id, label, price, sort_order FROM cake_sizes ORDER BY sort_order ASC, label ASC`,
    sql`SELECT id, label, sort_order FROM cake_flavors ORDER BY sort_order ASC, label ASC`,
    sql`SELECT id, label, sort_order FROM frosting_types ORDER BY sort_order ASC, label ASC`,
  ]);
  let toppingsRows = [];
  try {
    toppingsRows = await sql`SELECT id, label, sort_order FROM cake_toppings ORDER BY sort_order ASC, label ASC`;
  } catch {
    // cake_toppings may not exist until migration is run
  }
  return {
    sizes: (sizesRows || []).map(rowToSize).filter(Boolean),
    flavors: (flavorsRows || []).map(rowToOption).filter(Boolean),
    frostings: (frostingsRows || []).map(rowToOption).filter(Boolean),
    toppings: (toppingsRows || []).map(rowToOption).filter(Boolean),
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    const options = await getOptions();
    return res.status(200).json(options);
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const sizes = Array.isArray(body.sizes) ? body.sizes : [];
    const flavors = Array.isArray(body.flavors) ? body.flavors : [];
    const frostings = Array.isArray(body.frostings) ? body.frostings : [];
    const toppings = Array.isArray(body.toppings) ? body.toppings : [];

    await sql`DELETE FROM cake_sizes`;
    for (let i = 0; i < sizes.length; i++) {
      const s = sizes[i];
      const label = String(s?.label ?? '').trim();
      const price = Number(s?.price ?? 0);
      if (label) {
        await sql`INSERT INTO cake_sizes (label, price, sort_order) VALUES (${label}, ${price}, ${i})`;
      }
    }

    await sql`DELETE FROM cake_flavors`;
    for (let i = 0; i < flavors.length; i++) {
      const f = flavors[i];
      const label = String(f?.label ?? '').trim();
      if (label) {
        await sql`INSERT INTO cake_flavors (label, sort_order) VALUES (${label}, ${i})`;
      }
    }

    await sql`DELETE FROM frosting_types`;
    for (let i = 0; i < frostings.length; i++) {
      const f = frostings[i];
      const label = String(f?.label ?? '').trim();
      if (label) {
        await sql`INSERT INTO frosting_types (label, sort_order) VALUES (${label}, ${i})`;
      }
    }

    await sql`DELETE FROM cake_toppings`;
    for (let i = 0; i < toppings.length; i++) {
      const t = toppings[i];
      const label = String(t?.label ?? '').trim();
      if (label) {
        await sql`INSERT INTO cake_toppings (label, sort_order) VALUES (${label}, ${i})`;
      }
    }

    const options = await getOptions();
    return res.status(200).json(options);
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
