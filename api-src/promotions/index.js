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
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    const rows = await sql`SELECT * FROM promotions ORDER BY created_at DESC LIMIT 100`;
    return res.status(200).json(rows.map(rowToPromo));
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) {
      return res.status(403).json({ error: 'Admin required' });
    }
    const body = req.body || {};
    const code = (body.code && String(body.code).trim()) || '';
    const discountType = body.discountType || 'Percent off';
    const value = Number(body.value) || 0;
    const validFrom = body.validFrom ? new Date(body.validFrom) : null;
    const validTo = body.validTo ? new Date(body.validTo) : null;
    const isActive = body.isActive !== false;

    const rows = await sql`
      INSERT INTO promotions (code, discount_type, value, valid_from, valid_to, is_active)
      VALUES (${code}, ${discountType}, ${value}, ${validFrom}, ${validTo}, ${isActive})
      RETURNING *
    `;
    return res.status(201).json(rowToPromo(rows[0]));
  }

  res.status(405).json({ error: 'Method not allowed' });
}
