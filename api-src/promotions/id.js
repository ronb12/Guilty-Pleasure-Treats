import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToPromo(row) {
  if (!row) return null;
  return {
    id: row.id,
    code: row.code,
    discountType: row.discount_type,
    value: Number(row.value),
    validFrom: row.valid_from ? new Date(row.valid_from).toISOString() : null,
    validTo: row.valid_to ? new Date(row.valid_to).toISOString() : null,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'Promotion id required' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });

  if (req.method === 'PATCH') {
    const body = req.body || {};
    let rows = await sql`SELECT * FROM promotions WHERE id = ${id} LIMIT 1`;
    if (!rows.length) return res.status(404).json({ error: 'Promotion not found' });
    if (body.code !== undefined) await sql`UPDATE promotions SET code = ${String(body.code).trim()} WHERE id = ${id}`;
    if (body.discountType !== undefined) await sql`UPDATE promotions SET discount_type = ${String(body.discountType)} WHERE id = ${id}`;
    if (body.value !== undefined) await sql`UPDATE promotions SET value = ${Number(body.value)} WHERE id = ${id}`;
    if (body.validFrom !== undefined) await sql`UPDATE promotions SET valid_from = ${body.validFrom ? new Date(body.validFrom) : null} WHERE id = ${id}`;
    if (body.validTo !== undefined) await sql`UPDATE promotions SET valid_to = ${body.validTo ? new Date(body.validTo) : null} WHERE id = ${id}`;
    if (body.isActive !== undefined) await sql`UPDATE promotions SET is_active = ${Boolean(body.isActive)} WHERE id = ${id}`;
    rows = await sql`SELECT * FROM promotions WHERE id = ${id} LIMIT 1`;
    return res.status(200).json(rowToPromo(rows[0]));
  }

  if (req.method === 'DELETE') {
    const result = await sql`DELETE FROM promotions WHERE id = ${id} RETURNING id`;
    if (!result.length) return res.status(404).json({ error: 'Promotion not found' });
    return res.status(200).json({ ok: true });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
