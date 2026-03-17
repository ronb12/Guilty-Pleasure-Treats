/**
 * Product categories: public list; admin can POST new category.
 */
import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';

const DEFAULT_CATEGORIES = [
  { id: 'default-1', name: 'Cupcakes', displayOrder: 0 },
  { id: 'default-2', name: 'Cookies', displayOrder: 1 },
  { id: 'default-3', name: 'Cakes', displayOrder: 2 },
  { id: 'default-4', name: 'Brownies', displayOrder: 3 },
  { id: 'default-5', name: 'Seasonal Treats', displayOrder: 4 },
];

function rowToCategory(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name ?? '',
    displayOrder: Number(row.display_order ?? 0),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(200).json(DEFAULT_CATEGORIES);
  }

  if (req.method === 'GET') {
    try {
      const rows = await sql`
        SELECT * FROM product_categories ORDER BY display_order ASC, name ASC
      `;
      if (rows.length === 0) {
        return res.status(200).json(DEFAULT_CATEGORIES);
      }
      return res.status(200).json(rows.map(rowToCategory));
    } catch (err) {
      console.error('product-categories GET', err);
      return res.status(200).json(DEFAULT_CATEGORIES);
    }
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    if (!name) {
      return res.status(400).json({ error: 'name required' });
    }
    const displayOrder = body.displayOrder != null ? Number(body.displayOrder) : 0;
    try {
      const rows = await sql`
        INSERT INTO product_categories (name, display_order)
        VALUES (${name}, ${displayOrder})
        RETURNING *
      `;
      return res.status(201).json(rowToCategory(rows[0]));
    } catch (err) {
      if (err.code === '23505') return res.status(409).json({ error: 'A category with this name already exists' });
      console.error('product-categories POST', err);
      return res.status(500).json({ error: err.message || 'Failed to create category' });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
