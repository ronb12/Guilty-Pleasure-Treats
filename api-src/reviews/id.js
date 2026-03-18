/**
 * Single review: GET (public), PATCH/DELETE (admin).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToReview(row) {
  if (!row) return null;
  return {
    id: row.id,
    author: row.author ?? '',
    text: row.text ?? '',
    stars: Number(row.stars ?? 5),
    displayOrder: Number(row.display_order ?? 0),
    orderId: row.order_id ?? null,
    userId: row.user_id ?? null,
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

  const rows = await sql`SELECT * FROM reviews WHERE id = ${id} LIMIT 1`;
  const existing = rows[0];
  if (!existing) return res.status(404).json({ error: 'Not found' });

  if (req.method === 'GET') {
    return res.status(200).json(rowToReview(existing));
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  const isOwnReview = existing.user_id != null && session && String(existing.user_id) === String(session.userId);
  const canModify = session && (session.isAdmin || isOwnReview);

  if (req.method === 'PATCH' || req.method === 'DELETE') {
    if (!canModify) {
      return res.status(session ? 403 : 401).json({ error: session ? 'You can only edit or remove your own review.' : 'Sign in to continue.' });
    }
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const author = body.author !== undefined ? String(body.author).trim() || existing.author : existing.author;
    const text = body.text !== undefined ? String(body.text).trim() : existing.text;
    const stars = body.stars !== undefined ? Math.min(5, Math.max(1, parseInt(body.stars, 10) || 5)) : existing.stars;
    const displayOrder = body.displayOrder !== undefined ? Number(body.displayOrder) : existing.display_order;
    await sql`
      UPDATE reviews
      SET author = ${author}, text = ${text}, stars = ${stars}, display_order = ${displayOrder}, updated_at = NOW()
      WHERE id = ${id}
    `;
    const updated = await sql`SELECT * FROM reviews WHERE id = ${id} LIMIT 1`;
    return res.status(200).json(rowToReview(updated[0]));
  }

  if (req.method === 'DELETE') {
    await sql`DELETE FROM reviews WHERE id = ${id}`;
    return res.status(204).end();
  }

  res.status(405).json({ error: 'Method not allowed' });
}
