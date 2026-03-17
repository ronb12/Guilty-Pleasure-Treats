import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';

const placeholderProducts = [
  { id: '1', name: 'Classic Cupcake', category: 'Cupcakes', price: 3.5, description: '', imageURL: null, isFeatured: false, isSoldOut: false, isVegetarian: false, stockQuantity: 24, lowStockThreshold: 5, createdAt: null, updatedAt: null },
  { id: '2', name: 'Chocolate Chip Cookie', category: 'Cookies', price: 2.5, description: '', imageURL: null, isFeatured: false, isSoldOut: false, isVegetarian: false, stockQuantity: 36, lowStockThreshold: 8, createdAt: null, updatedAt: null },
  { id: '3', name: 'Vanilla Bean Cupcake', category: 'Cupcakes', price: 3.99, description: '', imageURL: null, isFeatured: false, isSoldOut: false, isVegetarian: false, stockQuantity: 12, lowStockThreshold: 4, createdAt: null, updatedAt: null },
  { id: '4', name: 'Birthday Cake (6 inch)', category: 'Cakes', price: 28, description: '', imageURL: null, isFeatured: true, isSoldOut: false, isVegetarian: false, stockQuantity: 3, lowStockThreshold: 1, createdAt: null, updatedAt: null },
  { id: '5', name: 'Chocolate Fudge Brownie', category: 'Brownies', price: 4, description: '', imageURL: null, isFeatured: false, isSoldOut: false, isVegetarian: false, stockQuantity: 20, lowStockThreshold: 5, createdAt: null, updatedAt: null },
];

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
    const isFeatured = Boolean(body.isFeatured);
    const isSoldOut = Boolean(body.isSoldOut);
    const isVegetarian = Boolean(body.isVegetarian);
    const stockQuantity = body.stockQuantity != null ? Number(body.stockQuantity) : null;
    const lowStockThreshold = body.lowStockThreshold != null ? Number(body.lowStockThreshold) : null;
    const cost = body.cost != null && body.cost !== '' ? Number(body.cost) : null;
    const rows = await sql`
      INSERT INTO products (name, description, price, cost, image_url, category, is_featured, is_sold_out, is_vegetarian, stock_quantity, low_stock_threshold)
      VALUES (${name}, ${description}, ${price}, ${cost}, ${imageURL}, ${category}, ${isFeatured}, ${isSoldOut}, ${isVegetarian}, ${stockQuantity}, ${lowStockThreshold})
      RETURNING *
    `;
    const row = rows[0];
    return res.status(201).json(rowToProduct(row));
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!hasDb() || !sql) {
    return res.status(200).json(placeholderProducts);
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
