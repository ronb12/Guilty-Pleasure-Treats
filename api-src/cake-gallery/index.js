/**
 * Cake gallery: public list for app; admin can POST new items.
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
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    try {
      const rows = await sql`
        SELECT * FROM cake_gallery
        ORDER BY display_order ASC, created_at DESC
      `;
      return res.status(200).json(rows.map(rowToItem));
    } catch (err) {
      // Table may not exist yet (run scripts/run-cake-gallery-schema.js on production)
      console.error('cake-gallery GET error:', err?.message || err);
      return res.status(200).json([]);
    }
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
    const body = req.body || {};
    const imageUrl = body.imageUrl ?? body.image_url ?? '';
    const title = (body.title ?? '').trim() || 'Treat';
    const description = (body.description ?? '').trim() || null;
    const category = (body.category ?? '').trim() || null;
    const price = body.price != null ? Number(body.price) : null;
    const displayOrder = body.displayOrder != null ? Number(body.displayOrder) : 0;
    if (!imageUrl) {
      return res.status(400).json({ error: 'imageUrl required' });
    }
    try {
      const rows = await sql`
        INSERT INTO cake_gallery (image_url, title, description, category, price, display_order)
        VALUES (${imageUrl}, ${title}, ${description}, ${category}, ${price}, ${displayOrder})
        RETURNING *
      `;
      return res.status(201).json(rowToItem(rows[0]));
    } catch (err) {
      console.error('cake-gallery POST', err);
      const code = err?.code || err?.code_;
      if (code === '42P01' || (err?.message && err.message.includes('does not exist'))) {
        return res.status(503).json({ error: 'Gallery not set up. Run scripts/run-cake-gallery-schema.js in production (Neon).' });
      }
      return res.status(500).json({ error: 'Failed to add gallery item. Please try again.' });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
