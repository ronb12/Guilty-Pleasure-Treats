/**
 * GET /api/promotions/code/:code — public lookup for valid, active promotion by code (checkout).
 */
import { sql, hasDb } from '../../lib/db.js';
import { setCors, handleOptions } from '../../lib/cors.js';
import { ensurePromotionsOptionalColumns } from '../../lib/promotionsSchema.js';

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
    minSubtotal: row.min_subtotal != null ? Number(row.min_subtotal) : null,
    minTotalQuantity: row.min_total_quantity != null ? Number(row.min_total_quantity) : null,
    firstOrderOnly: Boolean(row.first_order_only),
    productId: row.product_id != null && String(row.product_id).trim() !== '' ? String(row.product_id).trim() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const code = String(req.query?.code ?? '').trim().toUpperCase();
  if (!code) return res.status(400).json({ error: 'code is required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
  try {
    await ensurePromotionsOptionalColumns(sql);
    const rows = await sql`
      SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at,
             min_subtotal, min_total_quantity, first_order_only, product_id
      FROM promotions
      WHERE UPPER(TRIM(code)) = ${code}
      LIMIT 1
    `;
    const row = rows?.[0];
    if (!row || !row.is_active) return res.status(404).json({ error: 'Not found' });
    const now = new Date();
    if (row.valid_from && new Date(row.valid_from) > now) return res.status(404).json({ error: 'Not found' });
    if (row.valid_to && new Date(row.valid_to) < now) return res.status(404).json({ error: 'Not found' });
    return res.status(200).json(rowToPromotion(row));
  } catch (err) {
    if (err?.code === '42P01') return res.status(503).json({ error: 'Promotions not configured' });
    console.error('[promotions/code]', err);
    return res.status(500).json({ error: 'Failed to load promotion' });
  }
}
