/**
 * GET /api/ai-cake-designs — list (admin: all; user: own).
 * POST /api/ai-cake-designs — create AI design order row.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToAI(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? row.id,
    userId: row.user_id?.toString?.() ?? row.user_id ?? null,
    size: row.size ?? '',
    flavor: row.flavor ?? '',
    frosting: row.frosting ?? '',
    designPrompt: row.design_prompt ?? '',
    generatedImageURL: row.generated_image_url ?? null,
    price: Number(row.price ?? 0),
    orderId: row.order_id?.toString?.() ?? row.order_id ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;

  if (!hasDb() || !sql) {
    if ((req.method || '').toUpperCase() === 'GET') return res.status(200).json([]);
    return res.status(503).json({ error: 'Service unavailable' });
  }

  if ((req.method || '').toUpperCase() === 'GET') {
    if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
    const isAdmin = session.isAdmin === true;
    try {
      let rows;
      if (isAdmin) {
        rows = await sql`
          SELECT id, user_id, order_id, size, flavor, frosting, design_prompt, generated_image_url, price, created_at
          FROM ai_cake_designs
          ORDER BY created_at DESC NULLS LAST
          LIMIT 500
        `;
      } else {
        rows = await sql`
          SELECT id, user_id, order_id, size, flavor, frosting, design_prompt, generated_image_url, price, created_at
          FROM ai_cake_designs
          WHERE user_id::text = ${String(session.userId)}
          ORDER BY created_at DESC NULLS LAST
          LIMIT 200
        `;
      }
      return res.status(200).json((rows || []).map(rowToAI));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[ai-cake-designs] GET', err);
      return res.status(500).json({ error: 'Failed to fetch AI cake designs' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const body = req.body || {};
    const uid =
      session?.userId != null
        ? String(session.userId)
        : body.userId != null && String(body.userId).trim() !== ''
          ? String(body.userId).trim()
          : null;
    const size = String(body.size ?? '').trim();
    const flavor = String(body.flavor ?? '').trim();
    const frosting = String(body.frosting ?? '').trim();
    const designPrompt = String(body.designPrompt ?? body.design_prompt ?? '').trim();
    const price = body.price != null ? Number(body.price) : 0;
    const generatedImageURL = body.generatedImageURL ?? body.generated_image_url ?? null;
    if (!designPrompt) return res.status(400).json({ error: 'designPrompt is required' });
    try {
      const [row] = await sql`
        INSERT INTO ai_cake_designs (user_id, size, flavor, frosting, design_prompt, generated_image_url, price)
        VALUES (${uid}, ${size}, ${flavor}, ${frosting}, ${designPrompt}, ${generatedImageURL}, ${price})
        RETURNING id
      `;
      return res.status(201).json({ id: row?.id?.toString?.() ?? row?.id });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[ai-cake-designs] POST', err);
      return res.status(500).json({ error: 'Failed to save AI cake design' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
