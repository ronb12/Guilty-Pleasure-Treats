/**
 * PATCH /api/loyalty-rewards/id?id= — update (admin).
 * DELETE /api/loyalty-rewards/id?id= — delete (admin).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { pgBool, soldOutFromRow } from '../pgBool.js';
import { ensureLoyaltyRewardsTable } from '../lib/loyaltyRewardsSchema.js';

function rowSizeOptions(row) {
  const v = row.size_options;
  if (v == null) return null;
  if (Array.isArray(v) && v.length) return v;
  return null;
}

function rowToProduct(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? row.id,
    name: row.name,
    productDescription: row.description ?? '',
    description: row.description ?? '',
    price: Number(row.price),
    cost: row.cost != null ? Number(row.cost) : null,
    imageURL: row.image_url ?? null,
    category: row.category,
    isFeatured: pgBool(row.is_featured),
    isSoldOut: soldOutFromRow(row),
    isVegan: pgBool(row.is_vegan),
    stockQuantity: row.stock_quantity ?? null,
    lowStockThreshold: row.low_stock_threshold ?? null,
    sizeOptions: rowSizeOptions(row),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function mapJoinedRow(row) {
  const prodRow = {
    id: row.p_id,
    name: row.p_name,
    description: row.p_description,
    price: row.p_price,
    cost: row.p_cost,
    image_url: row.p_image_url,
    category: row.p_category,
    is_featured: row.p_is_featured,
    is_sold_out: row.p_is_sold_out,
    is_vegan: row.p_is_vegan,
    stock_quantity: row.p_stock_quantity,
    low_stock_threshold: row.p_low_stock_threshold,
    size_options: row.p_size_options,
    created_at: row.p_created_at,
    updated_at: row.p_updated_at,
  };
  return {
    id: row.lr_id?.toString?.() ?? row.lr_id,
    name: row.lr_name,
    pointsRequired: Number(row.lr_points_required),
    sortOrder: Number(row.lr_sort_order ?? 0),
    isActive: Boolean(row.lr_is_active),
    productId: row.product_id?.toString?.() ?? row.product_id,
    product: rowToProduct(prodRow),
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
  if (!id) return res.status(400).json({ error: 'Loyalty reward id required' });

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });

  if ((req.method || '').toUpperCase() === 'DELETE') {
    try {
      await ensureLoyaltyRewardsTable(sql);
      const result = await sql`DELETE FROM loyalty_rewards WHERE id = ${id}::uuid RETURNING id`;
      if (!result?.length) return res.status(404).json({ error: 'Reward not found' });
      return res.status(204).end();
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid reward id' });
      console.error('[loyalty-rewards/id] DELETE', err);
      return res.status(500).json({ error: 'Failed to delete reward' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const body = req.body || {};
    try {
      await ensureLoyaltyRewardsTable(sql);
      const [existing] = await sql`SELECT id FROM loyalty_rewards WHERE id = ${id}::uuid LIMIT 1`;
      if (!existing) return res.status(404).json({ error: 'Reward not found' });

      if (body.name != null) {
        const name = String(body.name).trim();
        if (!name) return res.status(400).json({ error: 'name cannot be empty' });
        await sql`UPDATE loyalty_rewards SET name = ${name}, updated_at = NOW() WHERE id = ${id}::uuid`;
      }
      if (body.pointsRequired != null || body.points_required != null) {
        const pr = Math.trunc(Number(body.pointsRequired ?? body.points_required));
        if (!Number.isFinite(pr) || pr < 1) return res.status(400).json({ error: 'pointsRequired must be at least 1' });
        await sql`UPDATE loyalty_rewards SET points_required = ${pr}, updated_at = NOW() WHERE id = ${id}::uuid`;
      }
      if (body.productId != null || body.product_id != null) {
        const productId = String(body.productId ?? body.product_id).trim();
        const [p] = await sql`SELECT id FROM products WHERE id = ${productId}::uuid LIMIT 1`;
        if (!p) return res.status(400).json({ error: 'Product not found' });
        await sql`UPDATE loyalty_rewards SET product_id = ${productId}::uuid, updated_at = NOW() WHERE id = ${id}::uuid`;
      }
      if (body.sortOrder != null || body.sort_order != null) {
        const so = Math.trunc(Number(body.sortOrder ?? body.sort_order ?? 0));
        await sql`UPDATE loyalty_rewards SET sort_order = ${so}, updated_at = NOW() WHERE id = ${id}::uuid`;
      }
      if (body.isActive !== undefined || body.is_active !== undefined) {
        const active = body.isActive !== undefined ? Boolean(body.isActive) : Boolean(body.is_active);
        await sql`UPDATE loyalty_rewards SET is_active = ${active}, updated_at = NOW() WHERE id = ${id}::uuid`;
      }

      const [row] = await sql`
        SELECT lr.id AS lr_id,
               lr.name AS lr_name,
               lr.points_required AS lr_points_required,
               lr.sort_order AS lr_sort_order,
               lr.is_active AS lr_is_active,
               lr.product_id AS product_id,
               p.id AS p_id,
               p.name AS p_name,
               p.description AS p_description,
               p.price AS p_price,
               p.cost AS p_cost,
               p.image_url AS p_image_url,
               p.category AS p_category,
               p.is_featured AS p_is_featured,
               p.is_sold_out AS p_is_sold_out,
               p.is_vegan AS p_is_vegan,
               p.stock_quantity AS p_stock_quantity,
               p.low_stock_threshold AS p_low_stock_threshold,
               p.size_options AS p_size_options,
               p.created_at AS p_created_at,
               p.updated_at AS p_updated_at
        FROM loyalty_rewards lr
        INNER JOIN products p ON p.id = lr.product_id
        WHERE lr.id = ${id}::uuid
        LIMIT 1
      `;
      if (!row) return res.status(404).json({ error: 'Reward not found' });
      return res.status(200).json(mapJoinedRow(row));
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid reward or product id' });
      if (err?.code === '23503') return res.status(400).json({ error: 'Invalid product' });
      console.error('[loyalty-rewards/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update reward' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
