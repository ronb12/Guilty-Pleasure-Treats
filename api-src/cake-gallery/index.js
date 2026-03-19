/**
 * GET /api/cake-gallery — list gallery items (public). Order by display_order, created_at.
 * POST /api/cake-gallery — add gallery item (admin). Body: { imageUrl, title, description?, category?, price? }.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

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

  if ((req.method || '').toUpperCase() === 'GET') {
    if (!hasDb() || !sql) return res.status(200).json([]);
    try {
      const rows = await sql`
        SELECT id, image_url, title, description, category, price, display_order, created_at, updated_at
        FROM cake_gallery
        ORDER BY display_order ASC, created_at DESC NULLS LAST
      `;
      return res.status(200).json((rows || []).map(rowToItem));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[cake-gallery] GET', err);
      return res.status(500).json({ error: 'Failed to fetch gallery' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) {
      return res.status(403).json({ error: 'Admin required' });
    }
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
    const body = req.body || {};
    const imageUrl = (body.imageUrl ?? body.image_url ?? '').toString().trim();
    const title = (body.title ?? '').toString().trim();
    if (!imageUrl || !title) {
      return res.status(400).json({ error: 'imageUrl and title are required' });
    }
    const description = body.description != null ? String(body.description) : null;
    const category = body.category != null ? String(body.category) : null;
    const price = body.price != null ? Number(body.price) : null;
    try {
      const [row] = await sql`
        INSERT INTO cake_gallery (image_url, title, description, category, price, display_order)
        VALUES (${imageUrl}, ${title}, ${description || null}, ${category || null}, ${price}, 0)
        RETURNING id, image_url, title, description, category, price, display_order, created_at, updated_at
      `;
      return res.status(201).json(rowToItem(row));
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[cake-gallery] POST', err);
      return res.status(500).json({ error: 'Failed to add gallery item' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
