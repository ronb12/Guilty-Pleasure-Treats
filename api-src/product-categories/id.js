/**
 * Single product category: PATCH (rename/reorder), DELETE (block if products use it).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

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
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'id required' });
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session || !session.isAdmin) {
    return res.status(401).json({ error: 'Admin required' });
  }

  const rows = await sql`SELECT * FROM product_categories WHERE id = ${id} LIMIT 1`;
  const existing = rows[0];
  if (!existing) return res.status(404).json({ error: 'Category not found' });

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const name = body.name !== undefined ? String(body.name).trim() : existing.name;
    const displayOrder = body.displayOrder !== undefined ? Number(body.displayOrder) : existing.display_order;
    if (!name) {
      return res.status(400).json({ error: 'name required' });
    }
    try {
      await sql`
        UPDATE product_categories SET name = ${name}, display_order = ${displayOrder}, updated_at = NOW()
        WHERE id = ${id}
      `;
      if (existing.name !== name) {
        await sql`UPDATE products SET category = ${name} WHERE category = ${existing.name}`;
      }
      const updated = await sql`SELECT * FROM product_categories WHERE id = ${id} LIMIT 1`;
      return res.status(200).json(rowToCategory(updated[0]));
    } catch (err) {
      if (err.code === '23505') return res.status(409).json({ error: 'A category with this name already exists' });
      console.error('product-categories PATCH', err);
      return res.status(500).json({ error: err.message || 'Failed to update category' });
    }
  }

  if (req.method === 'DELETE') {
    const used = await sql`SELECT 1 FROM products WHERE category = ${existing.name} LIMIT 1`;
    if (used.length > 0) {
      return res.status(400).json({ error: 'Cannot delete: one or more products use this category. Move or delete those products first.' });
    }
    await sql`DELETE FROM product_categories WHERE id = ${id}`;
    return res.status(204).end();
  }

  res.status(405).json({ error: 'Method not allowed' });
}
