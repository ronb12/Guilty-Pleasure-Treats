import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

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
    isFeatured: Boolean(row.is_featured),
    isSoldOut: Boolean(row.is_sold_out),
    isVegetarian: Boolean(row.is_vegetarian),
    stockQuantity: row.stock_quantity ?? null,
    lowStockThreshold: row.low_stock_threshold ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  const id = req.query?.id;
  if (!id) {
    return res.status(400).json({ error: 'Product id required' });
  }

  if (req.method === 'PATCH') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });
    const body = req.body || {};
    if (body.name !== undefined) await sql`UPDATE products SET name = ${String(body.name)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.description !== undefined) await sql`UPDATE products SET description = ${String(body.description)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.productDescription !== undefined) await sql`UPDATE products SET description = ${String(body.productDescription)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.price !== undefined) await sql`UPDATE products SET price = ${Number(body.price)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.imageURL !== undefined) await sql`UPDATE products SET image_url = ${body.imageURL}, updated_at = NOW() WHERE id = ${id}`;
    if (body.category !== undefined) await sql`UPDATE products SET category = ${String(body.category)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.isFeatured !== undefined) await sql`UPDATE products SET is_featured = ${Boolean(body.isFeatured)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.isSoldOut !== undefined) await sql`UPDATE products SET is_sold_out = ${Boolean(body.isSoldOut)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.isVegetarian !== undefined) await sql`UPDATE products SET is_vegetarian = ${Boolean(body.isVegetarian)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.stockQuantity !== undefined) await sql`UPDATE products SET stock_quantity = ${body.stockQuantity == null ? null : Number(body.stockQuantity)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.lowStockThreshold !== undefined) await sql`UPDATE products SET low_stock_threshold = ${body.lowStockThreshold == null ? null : Number(body.lowStockThreshold)}, updated_at = NOW() WHERE id = ${id}`;
    if (body.cost !== undefined) await sql`UPDATE products SET cost = ${body.cost == null || body.cost === '' ? null : Number(body.cost)}, updated_at = NOW() WHERE id = ${id}`;
    const rows = await sql`SELECT * FROM products WHERE id = ${id} LIMIT 1`;
    if (!rows[0]) return res.status(404).json({ error: 'Product not found' });
    return res.status(200).json(rowToProduct(rows[0]));
  }

  if (req.method === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });
    const rows = await sql`SELECT id FROM products WHERE id = ${id} LIMIT 1`;
    if (!rows[0]) return res.status(404).json({ error: 'Product not found' });
    await sql`DELETE FROM products WHERE id = ${id}`;
    return res.status(204).end();
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!hasDb() || !sql) {
    return res.status(404).json({ error: 'Product not found' });
  }

  try {
    const rows = await sql`SELECT * FROM products WHERE id = ${id} LIMIT 1`;
    const product = rows[0] ? rowToProduct(rows[0]) : null;
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.status(200).json(product);
  } catch (err) {
    console.error('products/[id] GET', err);
    res.status(500).json({ error: 'Failed to fetch product', details: err.message });
  }
}
