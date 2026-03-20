/**
 * GET /api/products/:id — one product (public).
 * PATCH /api/products/:id — update product (admin). Same body fields as POST /api/products.
 * DELETE /api/products/:id — delete product (admin).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { pgBool, bodyBool, soldOutFromRow } from '../pgBool.js';

function rowToProduct(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    productDescription: row.description ?? '',
    description: row.description ?? '',
    price: Number(row.price),
    cost: row.cost != null ? Number(row.cost) : null,
    imageURL: row.image_url ?? null,
    category: row.category,
    isFeatured: pgBool(row.is_featured),
    isSoldOut: soldOutFromRow(row),
    isVegetarian: pgBool(row.is_vegetarian),
    stockQuantity: row.stock_quantity ?? null,
    lowStockThreshold: row.low_stock_threshold ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
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
  if (!id) return res.status(400).json({ error: 'Product id required' });

  if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const [row] = await sql`
        SELECT * FROM products WHERE id = ${id}::uuid LIMIT 1
      `;
      if (!row) return res.status(404).json({ error: 'Product not found' });
      return res.status(200).json(rowToProduct(row));
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid product id' });
      console.error('[products/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch product', details: err.message });
    }
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });

  if ((req.method || '').toUpperCase() === 'DELETE') {
    try {
      const result = await sql`DELETE FROM products WHERE id = ${id}::uuid RETURNING id`;
      if (!result?.length) return res.status(404).json({ error: 'Product not found' });
      return res.status(204).end();
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid product id' });
      console.error('[products/id] DELETE', err);
      return res.status(500).json({ error: 'Failed to delete product', details: err.message });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const description = String(body.description ?? body.productDescription ?? '').trim();
    const price = Number(body.price) ?? 0;
    const imageURL = body.imageURL ?? null;
    const category = String(body.category ?? '').trim();
    const isFeatured = bodyBool(body.isFeatured);
    let isSoldOut = bodyBool(body.isSoldOut);
    const isVegetarian = bodyBool(body.isVegetarian);
    const stockQuantity = body.stockQuantity != null ? Number(body.stockQuantity) : null;
    const lowStockThreshold = body.lowStockThreshold != null ? Number(body.lowStockThreshold) : null;
    const cost = body.cost != null && body.cost !== '' ? Number(body.cost) : null;

    if (!name) return res.status(400).json({ error: 'Name is required' });

    // Positive stock means the item is available; clears stale is_sold_out after inventory-only edits.
    if (stockQuantity != null && !Number.isNaN(stockQuantity) && stockQuantity > 0) {
      isSoldOut = false;
    }

    const isAvailable = !isSoldOut;

    const patchProduct = () => sql`
      UPDATE products SET
        name = ${name},
        description = ${description},
        price = ${price},
        cost = ${cost},
        image_url = ${imageURL},
        category = ${category},
        is_featured = ${isFeatured},
        is_sold_out = ${isSoldOut},
        is_vegetarian = ${isVegetarian},
        stock_quantity = ${stockQuantity},
        low_stock_threshold = ${lowStockThreshold},
        is_available = ${isAvailable},
        updated_at = NOW()
      WHERE id = ${id}::uuid
      RETURNING *
    `;

    try {
      const [row] = await patchProduct();
      if (!row) return res.status(404).json({ error: 'Product not found' });
      return res.status(200).json(rowToProduct(row));
    } catch (err) {
      if (err?.code === '22P02') return res.status(400).json({ error: 'Invalid product id' });
      const missingVeg =
        err?.code === '42703' && String(err.message || '').includes('is_vegetarian');
      const missingAvail =
        err?.code === '42703' && String(err.message || '').includes('is_available');
      if (missingVeg || missingAvail) {
        try {
          if (missingVeg) {
            await sql`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegetarian BOOLEAN NOT NULL DEFAULT false`;
          }
          if (missingAvail) {
            await sql`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT true`;
          }
          const [row] = await patchProduct();
          if (!row) return res.status(404).json({ error: 'Product not found' });
          return res.status(200).json(rowToProduct(row));
        } catch (err2) {
          console.error('[products/id] PATCH after column migrate', err2);
          return res.status(500).json({ error: 'Failed to update product', details: err2.message });
        }
      }
      if (err?.code === '42703') {
        return res.status(500).json({
          error: 'Database schema out of date',
          details: err.message,
          hint: 'Run scripts/run-missing-tables.js or add missing columns on Neon (e.g. is_vegetarian).',
        });
      }
      console.error('[products/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update product', details: err.message });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
