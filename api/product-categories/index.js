/**
 * GET /api/product-categories - list categories (display_order, name).
 * POST /api/product-categories - add category (admin). Body: { name, displayOrder }.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToCategory(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    displayOrder: Number(row.display_order ?? 0),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
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
    if (!hasDb() || !sql) {
      return res.status(200).json([]);
    }
    try {
      const rows = await sql`
        SELECT id, name, display_order, created_at, updated_at
        FROM product_categories
        ORDER BY display_order ASC, name ASC
      `;
      return res.status(200).json(rows.map(rowToCategory));
    } catch (err) {
      console.error('[product-categories] GET', err);
      return res.status(500).json({ error: 'Failed to fetch categories' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) {
      return res.status(403).json({ error: 'Admin required' });
    }
    if (!hasDb() || !sql) {
      return res.status(503).json({ error: 'Database not configured' });
    }
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const displayOrder = Number(body.displayOrder ?? 0);
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    try {
      const rows = await sql`
        INSERT INTO product_categories (name, display_order)
        VALUES (${name}, ${displayOrder})
        RETURNING id, name, display_order, created_at, updated_at
      `;
      const row = rows[0];
      return res.status(201).json(rowToCategory(row));
    } catch (err) {
      console.error('[product-categories] POST', err);
      return res.status(500).json({ error: 'Failed to add category' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
