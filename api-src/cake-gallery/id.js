/**
 * Single cake gallery item: GET (public), PATCH/DELETE (admin).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToItem(row) {
  if (!row) return null;
  return {
    id: row.id,
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
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'id required' });
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const rows = await sql`SELECT * FROM cake_gallery WHERE id = ${id} LIMIT 1`;
  const existing = rows[0];
  if (!existing) return res.status(404).json({ error: 'Not found' });

  if (req.method === 'GET') {
    return res.status(200).json(rowToItem(existing));
  }

  if (req.method === 'PATCH' || req.method === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const now = new Date();
    const imageUrl = body.imageUrl !== undefined ? body.imageUrl : existing.image_url;
    const title = (body.title !== undefined ? String(body.title).trim() : existing.title) || 'Treat';
    const description = body.description !== undefined ? (String(body.description).trim() || null) : existing.description;
    const category = body.category !== undefined ? (String(body.category).trim() || null) : (existing.category ?? null);
    const price = body.price !== undefined ? (body.price == null ? null : Number(body.price)) : existing.price;
    const displayOrder = body.displayOrder !== undefined ? Number(body.displayOrder) : existing.display_order;
    await sql`
      UPDATE cake_gallery
      SET image_url = ${imageUrl}, title = ${title}, description = ${description}, category = ${category}, price = ${price}, display_order = ${displayOrder}, updated_at = ${now}
      WHERE id = ${id}
    `;
    const updated = await sql`SELECT * FROM cake_gallery WHERE id = ${id} LIMIT 1`;
    return res.status(200).json(rowToItem(updated[0]));
  }

  if (req.method === 'DELETE') {
    await sql`DELETE FROM cake_gallery WHERE id = ${id}`;
    return res.status(204).end();
  }

  res.status(405).json({ error: 'Method not allowed' });
}
