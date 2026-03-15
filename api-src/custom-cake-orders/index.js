import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToOrder(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id ?? null,
    size: row.size,
    flavor: row.flavor,
    frosting: row.frosting,
    message: row.message ?? '',
    designImageURL: row.design_image_url ?? null,
    price: Number(row.price),
    orderId: row.order_id ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'POST') {
    const body = req.body || {};
    const userId = body.userId ?? null;
    const size = body.size ?? '6 inch';
    const flavor = body.flavor ?? 'Vanilla';
    const frosting = body.frosting ?? 'Vanilla Buttercream';
    const message = body.message ?? '';
    const designImageURL = body.designImageURL ?? null;
    const price = Number(body.price) ?? 24;

    const rows = await sql`
      INSERT INTO custom_cake_orders (user_id, size, flavor, frosting, message, design_image_url, price)
      VALUES (${userId}, ${size}, ${flavor}, ${frosting}, ${message}, ${designImageURL}, ${price})
      RETURNING *
    `;
    return res.status(201).json(rowToOrder(rows[0]));
  }

  if (req.method === 'GET') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    const isAdmin = session?.isAdmin;
    let rows;
    if (isAdmin) {
      rows = await sql`SELECT * FROM custom_cake_orders ORDER BY created_at DESC LIMIT 100`;
    } else {
      const userId = session?.userId ?? req.query?.userId;
      if (!userId) return res.status(200).json([]);
      rows = await sql`SELECT * FROM custom_cake_orders WHERE user_id = ${userId} ORDER BY created_at DESC LIMIT 50`;
    }
    return res.status(200).json(rows.map(rowToOrder));
  }

  res.status(405).json({ error: 'Method not allowed' });
}
