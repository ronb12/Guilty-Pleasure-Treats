/**
 * GET /api/promotions/:id — get one promotion.
 * PATCH /api/promotions/:id — update promotion (admin).
 * DELETE /api/promotions/:id — delete promotion (admin).
 */
import { sql, hasDb } from '../../lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../lib/cors.js';

function rowToPromotion(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? row.id,
    code: row.code ?? '',
    discountType: row.discount_type ?? 'Percent off',
    value: Number(row.value ?? 0),
    validFrom: row.valid_from ? new Date(row.valid_from).toISOString() : null,
    validTo: row.valid_to ? new Date(row.valid_to).toISOString() : null,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'Promotion id required' });

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const [row] = await sql`
        SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at
        FROM promotions WHERE id = ${id}
      `;
      if (!row) return res.status(404).json({ error: 'Promotion not found' });
      return res.status(200).json(rowToPromotion(row));
    } catch (err) {
      if (err?.code === '42P01') return res.status(404).json({ error: 'Promotion not found' });
      console.error('[promotions/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch promotion' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH' || (req.method || '').toUpperCase() === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) return res.status(403).json({ error: 'Admin required' });

    if ((req.method || '').toUpperCase() === 'DELETE') {
      try {
        const result = await sql`DELETE FROM promotions WHERE id = ${id} RETURNING id`;
        if (!result?.length) return res.status(404).json({ error: 'Promotion not found' });
        return res.status(204).end();
      } catch (err) {
        if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
        console.error('[promotions/id] DELETE', err);
        return res.status(500).json({ error: 'Failed to delete promotion' });
      }
    }

    const body = req.body || {};
    const code = body.code != null ? String(body.code).trim().toUpperCase() : null;
    const discountType = body.discountType ?? body.discount_type ?? null;
    const value = body.value != null ? Number(body.value) : null;
    const isActive = body.isActive !== undefined ? Boolean(body.isActive) : (body.is_active !== undefined ? Boolean(body.is_active) : null);
    const validFrom = body.validFrom ?? body.valid_from ?? null;
    const validTo = body.validTo ?? body.valid_to ?? null;

    try {
      const [existing] = await sql`SELECT id FROM promotions WHERE id = ${id}`;
      if (!existing) return res.status(404).json({ error: 'Promotion not found' });

      if (code != null) await sql`UPDATE promotions SET code = ${code}, updated_at = NOW() WHERE id = ${id}`;
      if (discountType != null) await sql`UPDATE promotions SET discount_type = ${discountType}, updated_at = NOW() WHERE id = ${id}`;
      if (value != null) await sql`UPDATE promotions SET value = ${value}, updated_at = NOW() WHERE id = ${id}`;
      if (isActive !== null) await sql`UPDATE promotions SET is_active = ${isActive}, updated_at = NOW() WHERE id = ${id}`;
      if (validFrom !== undefined) await sql`UPDATE promotions SET valid_from = ${validFrom ? new Date(validFrom) : null}, updated_at = NOW() WHERE id = ${id}`;
      if (validTo !== undefined) await sql`UPDATE promotions SET valid_to = ${validTo ? new Date(validTo) : null}, updated_at = NOW() WHERE id = ${id}`;

      const [row] = await sql`
        SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at
        FROM promotions WHERE id = ${id}
      `;
      return res.status(200).json(rowToPromotion(row) ?? { id });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[promotions/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update promotion' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
