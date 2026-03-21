/**
 * GET /api/custom-cake-orders — list (admin: all; user: own).
 * POST /api/custom-cake-orders — create draft custom cake (auth optional; ties to session user when signed in).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToCustomCake(row) {
  if (!row) return null;
  let toppings = row.toppings;
  if (typeof toppings === 'string') {
    try {
      toppings = JSON.parse(toppings);
    } catch {
      toppings = [];
    }
  }
  if (!Array.isArray(toppings)) toppings = [];
  return {
    id: row.id?.toString?.() ?? row.id,
    userId: row.user_id?.toString?.() ?? row.user_id ?? null,
    size: row.size ?? '',
    flavor: row.flavor ?? '',
    frosting: row.frosting ?? '',
    toppings,
    message: row.message ?? '',
    designImageURL: row.design_image_url ?? null,
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
          SELECT id, user_id, order_id, size, flavor, frosting, toppings, message, design_image_url, price, created_at
          FROM custom_cake_orders
          ORDER BY created_at DESC NULLS LAST
          LIMIT 500
        `;
      } else {
        rows = await sql`
          SELECT id, user_id, order_id, size, flavor, frosting, toppings, message, design_image_url, price, created_at
          FROM custom_cake_orders
          WHERE user_id::text = ${String(session.userId)}
          ORDER BY created_at DESC NULLS LAST
          LIMIT 200
        `;
      }
      return res.status(200).json((rows || []).map(rowToCustomCake));
    } catch (err) {
      if (err?.code === '42703') {
        try {
          let rows;
          if (isAdmin) {
            rows = await sql`
              SELECT id, user_id, order_id, size, flavor, frosting, message, design_image_url, price, created_at
              FROM custom_cake_orders
              ORDER BY created_at DESC NULLS LAST
              LIMIT 500
            `;
          } else {
            rows = await sql`
              SELECT id, user_id, order_id, size, flavor, frosting, message, design_image_url, price, created_at
              FROM custom_cake_orders
              WHERE user_id::text = ${String(session.userId)}
              ORDER BY created_at DESC NULLS LAST
              LIMIT 200
            `;
          }
          return res.status(200).json((rows || []).map(rowToCustomCake));
        } catch (fallbackErr) {
          console.error('[custom-cake-orders] GET fallback', fallbackErr);
          return res.status(500).json({ error: 'Failed to fetch custom cake orders' });
        }
      }
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[custom-cake-orders] GET', err);
      return res.status(500).json({ error: 'Failed to fetch custom cake orders' });
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
    const message = String(body.message ?? '').trim();
    const price = body.price != null ? Number(body.price) : 0;
    const designImageURL = body.designImageURL ?? body.design_image_url ?? null;
    const toppingsArr = Array.isArray(body.toppings) ? body.toppings.map((t) => String(t)) : [];
    if (!size || !flavor || !frosting) {
      return res.status(400).json({ error: 'size, flavor, and frosting are required' });
    }
    try {
      let row;
      try {
        [row] = await sql`
          INSERT INTO custom_cake_orders (user_id, size, flavor, frosting, toppings, message, design_image_url, price)
          VALUES (${uid}, ${size}, ${flavor}, ${frosting}, ${JSON.stringify(toppingsArr)}::jsonb, ${message}, ${designImageURL}, ${price})
          RETURNING id, user_id, order_id, size, flavor, frosting, toppings, message, design_image_url, price, created_at
        `;
      } catch (insertErr) {
        if (insertErr?.code !== '42703') throw insertErr;
        [row] = await sql`
          INSERT INTO custom_cake_orders (user_id, size, flavor, frosting, message, design_image_url, price)
          VALUES (${uid}, ${size}, ${flavor}, ${frosting}, ${message}, ${designImageURL}, ${price})
          RETURNING id, user_id, order_id, size, flavor, frosting, message, design_image_url, price, created_at
        `;
      }
      const idStr = row?.id?.toString?.() ?? row?.id;
      try {
        const { isApnsConfigured, notifyNewCustomCakeRequest } = await import('../../api/lib/apns.js');
        if (isApnsConfigured()) {
          const adminRows = await sql`
            SELECT device_token FROM push_tokens
            WHERE is_admin = true AND device_token IS NOT NULL AND TRIM(device_token) != ''
          `;
          const tokens = (adminRows || []).map((r) => r.device_token).filter(Boolean);
          if (tokens.length) {
            const summary = [size, flavor, frosting].filter(Boolean).join(' · ') || 'Custom cake';
            notifyNewCustomCakeRequest(tokens, idStr ? String(idStr) : '', summary);
          }
        }
      } catch (pushErr) {
        console.warn('[custom-cake-orders] push', pushErr?.message ?? pushErr);
      }

      return res.status(201).json({ id: idStr });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[custom-cake-orders] POST', err);
      return res.status(500).json({ error: 'Failed to save custom cake order' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
