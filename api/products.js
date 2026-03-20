import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';
import { pgBool, bodyBool, soldOutFromRow } from './pgBool.js';

/** When DATABASE_URL is unset (local/static hosting), return an empty list — production uses Neon. */
const emptyProductsList = [];

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
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const description = String(body.description ?? body.productDescription ?? '').trim();
    const price = Number(body.price) ?? 0;
    const imageURL = body.imageURL ?? null;
    const category = String(body.category ?? '').trim();
    const isFeatured = bodyBool(body.isFeatured);
    const isSoldOut = bodyBool(body.isSoldOut);
    const isVegetarian = bodyBool(body.isVegetarian);
    const stockQuantity = body.stockQuantity != null ? Number(body.stockQuantity) : null;
    const lowStockThreshold = body.lowStockThreshold != null ? Number(body.lowStockThreshold) : null;
    const cost = body.cost != null && body.cost !== '' ? Number(body.cost) : null;
    /** Keep in sync with is_sold_out: available for sale unless marked sold out. */
    const isAvailable = !isSoldOut;
    const insertProduct = () => sql`
      INSERT INTO products (name, description, price, cost, image_url, category, is_featured, is_sold_out, is_vegetarian, stock_quantity, low_stock_threshold, is_available)
      VALUES (${name}, ${description}, ${price}, ${cost}, ${imageURL}, ${category}, ${isFeatured}, ${isSoldOut}, ${isVegetarian}, ${stockQuantity}, ${lowStockThreshold}, ${isAvailable})
      RETURNING *
    `;
    try {
      const rows = await insertProduct();
      const row = rows[0];
      return res.status(201).json(rowToProduct(row));
    } catch (err) {
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
          const rows = await insertProduct();
          const row = rows[0];
          return res.status(201).json(rowToProduct(row));
        } catch (err2) {
          console.error('products POST after column migrate', err2);
          return res.status(500).json({ error: 'Failed to create product', details: err2.message });
        }
      }
      if (err?.code === '42703') {
        return res.status(500).json({
          error: 'Database schema out of date',
          details: err.message,
          hint: 'On Neon, run: ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegetarian BOOLEAN NOT NULL DEFAULT false; or node scripts/run-missing-tables.js',
        });
      }
      console.error('products POST', err);
      return res.status(500).json({ error: 'Failed to create product', details: err.message });
    }
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!hasDb() || !sql) {
    return res.status(200).json(emptyProductsList);
  }

  try {
    const { category, featured } = req.query || {};
    const cat = category && String(category).trim() ? String(category).trim() : null;
    const feat = featured === 'true' || featured === '1';

    let rows;
    if (cat && feat) {
      rows = await sql`SELECT * FROM products WHERE category = ${cat} AND is_featured = true ORDER BY created_at DESC NULLS LAST`;
    } else if (cat) {
      rows = await sql`SELECT * FROM products WHERE category = ${cat} ORDER BY created_at DESC NULLS LAST`;
    } else if (feat) {
      rows = await sql`SELECT * FROM products WHERE is_featured = true ORDER BY created_at DESC NULLS LAST`;
    } else {
      rows = await sql`SELECT * FROM products ORDER BY created_at DESC NULLS LAST`;
    }
    const products = rows.map(rowToProduct);
    res.status(200).json(products);
  } catch (err) {
    console.error('products GET', err);
    res.status(500).json({ error: 'Failed to fetch products', details: err.message });
  }
}
