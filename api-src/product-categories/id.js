/**
 * GET /api/product-categories/:id - get one category.
 * PATCH /api/product-categories/:id - update (admin). Body: { name?, displayOrder? }.
 * DELETE /api/product-categories/:id - delete (admin).
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
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'Missing id' });

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const rows = await sql`
        SELECT id, name, display_order, created_at, updated_at
        FROM product_categories WHERE (id)::text = ${String(id)} LIMIT 1
      `;
      if (!rows.length) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json(rowToCategory(rows[0]));
    } catch (err) {
      console.error('[product-categories/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch category' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    const body = req.body || {};
    const name = body.name != null ? String(body.name).trim() : null;
    const displayOrder = body.displayOrder != null ? Number(body.displayOrder) : null;
    if (name == null && displayOrder == null) {
      return res.status(400).json({ error: 'No updates provided' });
    }
    try {
      if (name != null && displayOrder != null) {
        await sql`
          UPDATE product_categories
          SET name = ${name}, display_order = ${displayOrder}, updated_at = NOW()
          WHERE (id)::text = ${String(id)}
        `;
      } else if (name != null) {
        await sql`UPDATE product_categories SET name = ${name}, updated_at = NOW() WHERE (id)::text = ${String(id)}`;
      } else if (displayOrder != null) {
        await sql`UPDATE product_categories SET display_order = ${displayOrder}, updated_at = NOW() WHERE (id)::text = ${String(id)}`;
      }
      const rows = await sql`
        SELECT id, name, display_order, created_at, updated_at
        FROM product_categories
        WHERE (id)::text = ${String(id)}
        LIMIT 1
      `;
      if (!rows.length) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json(rowToCategory(rows[0]));
    } catch (err) {
      if (err?.code === '23505') {
        return res.status(409).json({ error: 'A category with this name already exists' });
      }
      console.error('[product-categories/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update category' });
    }
  }

  if ((req.method || '').toUpperCase() === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    try {
      await sql`DELETE FROM product_categories WHERE (id)::text = ${String(id)}`;
      return res.status(204).end();
    } catch (err) {
      console.error('[product-categories/id] DELETE', err);
      return res.status(500).json({ error: 'Failed to delete category' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
