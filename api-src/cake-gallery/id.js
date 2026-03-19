/**
 * GET /api/cake-gallery/:id — get one gallery item (public).
 * PATCH /api/cake-gallery/:id — update (admin). Body: { imageUrl?, title?, description?, category?, price?, displayOrder? }.
 * DELETE /api/cake-gallery/:id — delete (admin).
 */
import { sql, hasDb } from '../../lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../lib/cors.js';

function rowToItem(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    imageUrl: row.image_url ?? null,
    title: row.title ?? '',
    description: row.description ?? null,
    category: row.category ?? null,
    price: row.price != null ? Number(row.price) : null,
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
  if (!id) return res.status(400).json({ error: 'id required' });

  if ((req.method || '').toUpperCase() === 'PATCH' || (req.method || '').toUpperCase() === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) {
      return res.status(403).json({ error: 'Admin required' });
    }
  }

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  try {
    if ((req.method || '').toUpperCase() === 'GET') {
      const [row] = await sql`
        SELECT id, image_url, title, description, category, price, display_order, created_at, updated_at
        FROM cake_gallery
        WHERE id = ${id}
        LIMIT 1
      `;
      if (!row) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json(rowToItem(row));
    }

    if ((req.method || '').toUpperCase() === 'PATCH') {
      const [existing] = await sql`
        SELECT id, image_url, title, description, category, price, display_order
        FROM cake_gallery WHERE id = ${id} LIMIT 1
      `;
      if (!existing) return res.status(404).json({ error: 'Not found' });
      const body = req.body || {};
      const imageUrl = body.imageUrl !== undefined ? String(body.imageUrl) : existing.image_url;
      const title = body.title !== undefined ? String(body.title) : existing.title;
      const description = body.description !== undefined ? (body.description == null ? null : String(body.description)) : existing.description;
      const category = body.category !== undefined ? (body.category == null ? null : String(body.category)) : existing.category;
      const price = body.price !== undefined ? (body.price == null ? null : Number(body.price)) : existing.price;
      const displayOrder = body.displayOrder !== undefined ? Number(body.displayOrder) : existing.display_order;
      await sql`
        UPDATE cake_gallery
        SET image_url = ${imageUrl}, title = ${title}, description = ${description}, category = ${category}, price = ${price}, display_order = ${displayOrder}, updated_at = NOW()
        WHERE id = ${id}
      `;
      const [row] = await sql`
        SELECT id, image_url, title, description, category, price, display_order, created_at, updated_at
        FROM cake_gallery WHERE id = ${id} LIMIT 1
      `;
      return res.status(200).json(rowToItem(row));
    }

    if ((req.method || '').toUpperCase() === 'DELETE') {
      const result = await sql`DELETE FROM cake_gallery WHERE id = ${id} RETURNING id`;
      if (!result || result.length === 0) return res.status(404).json({ error: 'Not found' });
      return res.status(204).end();
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
    console.error('[cake-gallery/id]', err);
    return res.status(500).json({ error: 'Server error' });
  }
}
