/**
 * GET /api/loyalty-rewards — active rewards + product (public). Admin session: all rows.
 * POST /api/loyalty-rewards — create (admin). Body: name, pointsRequired, productId, sortOrder?, isActive?
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { pgBool, soldOutFromRow } from '../pgBool.js';
import { ensureLoyaltyRewardsTable } from '../../api/lib/loyaltyRewardsSchema.js';

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

/** Map joined row with lr_* and p_* column prefixes from SELECT. */
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

async function fetchRewardsJoined(sqlConn, { asAdmin }) {
  if (asAdmin) {
    return sqlConn`
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
      ORDER BY lr.sort_order ASC, lr.name ASC
    `;
  }
  return sqlConn`
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
    WHERE lr.is_active = true
    ORDER BY lr.sort_order ASC, lr.name ASC
  `;
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  const includeInactive =
    req.query?.includeInactive === '1' || req.query?.include_inactive === '1';
  const asAdmin = session?.isAdmin === true && includeInactive;

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      await ensureLoyaltyRewardsTable(sql);
      const rows = await fetchRewardsJoined(sql, { asAdmin });
      return res.status(200).json((rows || []).map(mapJoinedRow));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[loyalty-rewards] GET', err);
      return res.status(500).json({ error: 'Failed to fetch loyalty rewards' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    if (!asAdmin) return res.status(403).json({ error: 'Admin required' });
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const pointsRequired = Math.trunc(Number(body.pointsRequired ?? body.points_required ?? 0));
    const productId = String(body.productId ?? body.product_id ?? '').trim();
    const sortOrder = body.sortOrder != null || body.sort_order != null
      ? Math.trunc(Number(body.sortOrder ?? body.sort_order ?? 0))
      : 0;
    const isActive = body.isActive !== false && body.is_active !== false;
    if (!name) return res.status(400).json({ error: 'name is required' });
    if (!Number.isFinite(pointsRequired) || pointsRequired < 1) {
      return res.status(400).json({ error: 'pointsRequired must be at least 1' });
    }
    if (!productId) return res.status(400).json({ error: 'productId is required' });

    try {
      await ensureLoyaltyRewardsTable(sql);
      const [p] = await sql`SELECT id FROM products WHERE id = ${productId}::uuid LIMIT 1`;
      if (!p) return res.status(400).json({ error: 'Product not found' });

      const [row] = await sql`
        INSERT INTO loyalty_rewards (name, points_required, product_id, sort_order, is_active)
        VALUES (${name}, ${pointsRequired}, ${productId}::uuid, ${sortOrder}, ${isActive})
        RETURNING id
      `;
      const id = row?.id?.toString?.() ?? row?.id;
      return res.status(201).json({ id });
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid product id' });
      if (err?.code === '23503') return res.status(400).json({ error: 'Invalid product' });
      console.error('[loyalty-rewards] POST', err);
      return res.status(500).json({ error: 'Failed to create loyalty reward' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
