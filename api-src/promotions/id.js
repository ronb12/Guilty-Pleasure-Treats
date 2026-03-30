/**
 * GET /api/promotions/:id — get one promotion.
 * PATCH /api/promotions/:id — update promotion (admin).
 * DELETE /api/promotions/:id — delete promotion (admin).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { ensurePromotionsOptionalColumns } from '../lib/promotionsSchema.js';

/** Apply PATCH fields; throws on DB errors. Caller ensures row exists or handles 404. */
async function applyPromotionPatch(sql, id, fields) {
  const {
    code,
    discountType,
    value,
    isActive,
    validFrom,
    validTo,
    minSubIn,
    minQtyIn,
    firstOrderIn,
    productIdIn,
  } = fields;

  if (code != null) {
    if (!code) {
      const e = new Error('Code cannot be empty');
      e.statusCode = 400;
      throw e;
    }
    await sql`UPDATE promotions SET code = ${code}, updated_at = NOW() WHERE id = ${id}::uuid`;
  }
  if (discountType != null) await sql`UPDATE promotions SET discount_type = ${discountType}, updated_at = NOW() WHERE id = ${id}::uuid`;
  if (value != null) await sql`UPDATE promotions SET value = ${value}, updated_at = NOW() WHERE id = ${id}::uuid`;
  if (isActive !== null) await sql`UPDATE promotions SET is_active = ${isActive}, updated_at = NOW() WHERE id = ${id}::uuid`;
  if (validFrom !== undefined) await sql`UPDATE promotions SET valid_from = ${validFrom ? new Date(validFrom) : null}, updated_at = NOW() WHERE id = ${id}::uuid`;
  if (validTo !== undefined) await sql`UPDATE promotions SET valid_to = ${validTo ? new Date(validTo) : null}, updated_at = NOW() WHERE id = ${id}::uuid`;
  if (minSubIn !== undefined) {
    const n = minSubIn == null ? null : Number(minSubIn);
    const dbVal = n != null && Number.isFinite(n) && n > 0 ? n : null;
    await sql`UPDATE promotions SET min_subtotal = ${dbVal}, updated_at = NOW() WHERE id = ${id}::uuid`;
  }
  if (minQtyIn !== undefined) {
    const n = minQtyIn == null ? null : Math.trunc(Number(minQtyIn));
    const dbVal = n != null && Number.isFinite(n) && n > 0 ? n : null;
    await sql`UPDATE promotions SET min_total_quantity = ${dbVal}, updated_at = NOW() WHERE id = ${id}::uuid`;
  }
  if (firstOrderIn !== undefined) {
    await sql`UPDATE promotions SET first_order_only = ${Boolean(firstOrderIn)}, updated_at = NOW() WHERE id = ${id}::uuid`;
  }
  if (productIdIn !== undefined) {
    const pid =
      productIdIn == null || String(productIdIn).trim() === '' ? null : String(productIdIn).trim();
    await sql`UPDATE promotions SET product_id = ${pid}, updated_at = NOW() WHERE id = ${id}::uuid`;
  }

  const [row] = await sql`
    SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at,
           min_subtotal, min_total_quantity, first_order_only, product_id
    FROM promotions WHERE id = ${id}::uuid
  `;
  return rowToPromotion(row) ?? { id };
}

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
  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'Promotion id required' });

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      await ensurePromotionsOptionalColumns(sql);
      const [row] = await sql`
        SELECT id, code, discount_type, value, valid_from, valid_to, is_active, created_at,
               min_subtotal, min_total_quantity, first_order_only, product_id
        FROM promotions WHERE id = ${id}::uuid
      `;
      if (!row) return res.status(404).json({ error: 'Promotion not found' });
      return res.status(200).json(rowToPromotion(row));
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid promotion id' });
      if (err?.code === '42P01') return res.status(404).json({ error: 'Promotion not found' });
      console.error('[promotions/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch promotion' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH' || (req.method || '').toUpperCase() === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });

    if ((req.method || '').toUpperCase() === 'DELETE') {
      try {
        const result = await sql`DELETE FROM promotions WHERE id = ${id}::uuid RETURNING id`;
        if (!result?.length) return res.status(404).json({ error: 'Promotion not found' });
        return res.status(204).end();
      } catch (err) {
        if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid promotion id' });
        if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
        console.error('[promotions/id] DELETE', err);
        return res.status(500).json({ error: 'Failed to delete promotion' });
      }
    }

    const body = req.body || {};
    const code = body.code != null ? String(body.code).trim().toUpperCase() : null;
    const discountType = body.discountType ?? body.discount_type ?? null;
    const valueRaw = body.value != null ? Number(body.value) : null;
    const value = valueRaw != null && Number.isFinite(valueRaw) ? valueRaw : null;
    const isActive = body.isActive !== undefined ? Boolean(body.isActive) : (body.is_active !== undefined ? Boolean(body.is_active) : null);
    const validFrom = body.validFrom ?? body.valid_from ?? null;
    const validTo = body.validTo ?? body.valid_to ?? null;
    const minSubIn = body.minSubtotal !== undefined || body.min_subtotal !== undefined
      ? (body.minSubtotal ?? body.min_subtotal)
      : undefined;
    const minQtyIn = body.minTotalQuantity !== undefined || body.min_total_quantity !== undefined
      ? (body.minTotalQuantity ?? body.min_total_quantity)
      : undefined;
    const firstOrderIn = body.firstOrderOnly !== undefined || body.first_order_only !== undefined
      ? (body.firstOrderOnly ?? body.first_order_only)
      : undefined;
    const productIdIn =
      body.productId !== undefined || body.product_id !== undefined
        ? (body.productId ?? body.product_id)
        : undefined;

    const patchFields = {
      code,
      discountType,
      value,
      isActive,
      validFrom,
      validTo,
      minSubIn,
      minQtyIn,
      firstOrderIn,
      productIdIn,
    };

    try {
      await ensurePromotionsOptionalColumns(sql);
      const [existing] = await sql`SELECT id FROM promotions WHERE id = ${id}::uuid`;
      if (!existing) return res.status(404).json({ error: 'Promotion not found' });

      const json = await applyPromotionPatch(sql, id, patchFields);
      return res.status(200).json(json);
    } catch (err) {
      if (err?.statusCode === 400) return res.status(400).json({ error: err.message || 'Bad request' });
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid promotion id' });
      if (err?.code === '23505') return res.status(409).json({ error: 'A promotion with this code already exists' });
      if (err?.code === '42703') {
        try {
          await ensurePromotionsOptionalColumns(sql);
          console.warn('[promotions/id] Self-heal after 42703:', err?.message);
        } catch (migrateErr) {
          console.error('[promotions/id] PATCH schema migration failed', migrateErr);
          return res.status(503).json({ error: 'Database schema out of date. Run scripts/sql/fix-promotions-updated-at.sql in Neon.' });
        }
        try {
          await ensurePromotionsOptionalColumns(sql);
          const [existing2] = await sql`SELECT id FROM promotions WHERE id = ${id}::uuid`;
          if (!existing2) return res.status(404).json({ error: 'Promotion not found' });
          const json = await applyPromotionPatch(sql, id, patchFields);
          return res.status(200).json(json);
        } catch (err2) {
          if (err2?.code === '22P02') return res.status(400).json({ error: 'Invalid promotion id' });
          if (err2?.code === '23505') return res.status(409).json({ error: 'A promotion with this code already exists' });
          console.error('[promotions/id] PATCH retry after schema heal', err2?.code, err2?.message, err2);
          return res.status(500).json({ error: 'Failed to update promotion' });
        }
      }
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[promotions/id] PATCH', err?.code, err?.message, err);
      return res.status(500).json({ error: 'Failed to update promotion' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
