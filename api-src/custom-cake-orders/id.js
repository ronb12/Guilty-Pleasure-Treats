import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

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

  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'Order id required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });

  if (req.method === 'PATCH') {
    const body = req.body || {};
    if (body.designImageURL !== undefined) await sql`UPDATE custom_cake_orders SET design_image_url = ${body.designImageURL} WHERE id = ${id}`;
    if (body.orderId !== undefined) await sql`UPDATE custom_cake_orders SET order_id = ${body.orderId} WHERE id = ${id}`;
    const rows = await sql`SELECT * FROM custom_cake_orders WHERE id = ${id} LIMIT 1`;
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    return res.status(200).json(rowToOrder(rows[0]));
  }

  res.status(405).json({ error: 'Method not allowed' });
}
