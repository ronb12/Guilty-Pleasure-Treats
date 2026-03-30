/**
 * GET /api/promotions — list promotions (admin or public for listing).
 * POST /api/promotions — add promotion (admin). Body: code, discountType, value, validFrom?, validTo?, isActive.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { ensurePromotionsOptionalColumns } from '../lib/promotionsSchema.js';

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

  if ((req.method || '').toUpperCase() === 'GET') {
    if (!hasDb() || !sql) return res.status(200).json([]);
    try {
      await ensurePromotionsOptionalColumns(sql);
      const rows = await sql`
        SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at,
               min_subtotal, min_total_quantity, first_order_only, product_id
        FROM promotions
        ORDER BY created_at DESC NULLS LAST
        LIMIT 200
      `;
      return res.status(200).json((rows || []).map(rowToPromotion));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[promotions] GET', err);
      return res.status(500).json({ error: 'Failed to fetch promotions' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

    const body = req.body || {};
    const code = String(body.code ?? '').trim().toUpperCase();
    const discountType = String(body.discountType ?? body.discount_type ?? 'Percent off').trim();
    const value = Number(body.value ?? 0);
    const isActive = body.isActive !== false && body.is_active !== false;
    const validFrom = body.validFrom ?? body.valid_from ?? null;
    const validTo = body.validTo ?? body.valid_to ?? null;
    const minSub = body.minSubtotal != null ? Number(body.minSubtotal) : (body.min_subtotal != null ? Number(body.min_subtotal) : null);
    const minQty = body.minTotalQuantity != null ? Math.trunc(Number(body.minTotalQuantity)) : (body.min_total_quantity != null ? Math.trunc(Number(body.min_total_quantity)) : null);
    const firstOrderOnly = body.firstOrderOnly === true || body.first_order_only === true;
    const minSubDb = minSub != null && Number.isFinite(minSub) && minSub > 0 ? minSub : null;
    const minQtyDb = minQty != null && Number.isFinite(minQty) && minQty > 0 ? minQty : null;
    const rawPid = body.productId ?? body.product_id;
    const productIdDb =
      rawPid != null && String(rawPid).trim() !== '' ? String(rawPid).trim() : null;
    if (!code) return res.status(400).json({ error: 'code is required' });

    try {
      await ensurePromotionsOptionalColumns(sql);
      const [row] = await sql`
        INSERT INTO promotions (code, discount_type, value, valid_from, valid_to, is_active, min_subtotal, min_total_quantity, first_order_only, product_id)
        VALUES (${code}, ${discountType}, ${value},
          ${validFrom ? new Date(validFrom) : null},
          ${validTo ? new Date(validTo) : null},
          ${isActive}, ${minSubDb}, ${minQtyDb}, ${firstOrderOnly}, ${productIdDb})
        RETURNING id, code, discount_type, value, valid_from, valid_to, is_active, created_at
      `;
      return res.status(201).json({ id: row?.id?.toString?.() ?? row?.id });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Promotions table not set up. Run schema to create it.' });
      if (err?.code === '23505') return res.status(409).json({ error: 'A promotion with this code already exists' });
      if (err?.code === '42703') {
        console.error('[promotions] POST missing column — run scripts/run-missing-tables.js or Neon SQL', err?.message);
        return res.status(503).json({
          error: 'Promotions table is missing columns (min_subtotal / first_order_only / etc.). Run DB migration or redeploy.',
        });
      }
      console.error('[promotions] POST', err);
      return res.status(500).json({ error: 'Failed to add promotion' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
