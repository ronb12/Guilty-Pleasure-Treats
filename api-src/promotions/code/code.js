import { sql, hasDb } from '../../../api/lib/db.js';
import { setCors, handleOptions } from '../../../api/lib/cors.js';

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
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const code = req.query?.code;
  if (!code) {
    return res.status(400).json({ error: 'Code required' });
  }

  if (!hasDb() || !sql) {
    return res.status(404).json(null);
  }

  const rows = await sql`SELECT * FROM promotions WHERE code = ${String(code).trim()} AND is_active = true LIMIT 1`;
  const promo = rows[0];
  if (!promo) {
    return res.status(404).json(null);
  }
  const now = new Date();
  if (promo.valid_from && new Date(promo.valid_from) > now) {
    return res.status(404).json(null);
  }
  if (promo.valid_to && new Date(promo.valid_to) < now) {
    return res.status(404).json(null);
  }
  res.status(200).json(rowToPromo(promo));
}
