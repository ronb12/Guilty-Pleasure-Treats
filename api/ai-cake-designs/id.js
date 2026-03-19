/**
 * PATCH /api/ai-cake-designs/:id — update generatedImageURL, orderId (owner or admin).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'PATCH') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'id required' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  try {
    const [existing] = await sql`
      SELECT id, user_id, generated_image_url, order_id FROM ai_cake_designs WHERE id = ${id}::uuid LIMIT 1
    `;
    if (!existing) return res.status(404).json({ error: 'Not found' });
    const ownerId = existing.user_id?.toString?.() ?? existing.user_id;
    const sessionId = session.userId?.toString?.() ?? session.userId;
    if (ownerId !== sessionId && session.isAdmin !== true) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const body = req.body || {};
    let nextImg = existing.generated_image_url;
    if (Object.prototype.hasOwnProperty.call(body, 'generatedImageURL')) nextImg = body.generatedImageURL;
    if (Object.prototype.hasOwnProperty.call(body, 'generated_image_url')) nextImg = body.generated_image_url;
    let nextOrderId = existing.order_id;
    if (Object.prototype.hasOwnProperty.call(body, 'orderId') || Object.prototype.hasOwnProperty.call(body, 'order_id')) {
      const oid = body.orderId ?? body.order_id;
      nextOrderId = oid === '' || oid == null ? null : oid;
    }

    const [row] = await sql`
      UPDATE ai_cake_designs
      SET generated_image_url = ${nextImg}, order_id = ${nextOrderId}::uuid
      WHERE id = ${id}::uuid
      RETURNING id
    `;
    if (!row) return res.status(404).json({ error: 'Not found' });
    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[ai-cake-designs/id] PATCH', err);
    return res.status(500).json({ error: 'Update failed' });
  }
}
