import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToDesign(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id ?? null,
    size: row.size,
    flavor: row.flavor,
    frosting: row.frosting,
    designPrompt: row.design_prompt ?? '',
    generatedImageURL: row.generated_image_url ?? null,
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
    const frosting = body.frosting ?? 'Buttercream';
    const designPrompt = body.designPrompt ?? '';
    const generatedImageURL = body.generatedImageURL ?? null;
    const price = Number(body.price) ?? 28;

    const rows = await sql`
      INSERT INTO ai_cake_designs (user_id, size, flavor, frosting, design_prompt, generated_image_url, price)
      VALUES (${userId}, ${size}, ${flavor}, ${frosting}, ${designPrompt}, ${generatedImageURL}, ${price})
      RETURNING *
    `;
    return res.status(201).json(rowToDesign(rows[0]));
  }

  if (req.method === 'GET') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    const isAdmin = session?.isAdmin;
    let rows;
    if (isAdmin) {
      rows = await sql`SELECT * FROM ai_cake_designs ORDER BY created_at DESC LIMIT 100`;
    } else {
      const userId = session?.userId ?? req.query?.userId;
      if (!userId) return res.status(200).json([]);
      rows = await sql`SELECT * FROM ai_cake_designs WHERE user_id = ${userId} ORDER BY created_at DESC LIMIT 50`;
    }
    return res.status(200).json(rows.map(rowToDesign));
  }

  res.status(405).json({ error: 'Method not allowed' });
}
