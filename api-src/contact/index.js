/**
 * GET /api/contact - list contact messages (admin only).
 *   Query: ?quotesOnly=1 — gallery quote requests (rows in quote_requests + contact_messages).
 *   Query: ?excludeQuotes=1 — general contact only (no row in quote_requests).
 * POST /api/contact - submit a contact message (public).
 * Body: { name?, email, subject?, message, userId?, orderId?, source?, galleryItemTitle? }.
 * source=gallery_quote → inserts contact_messages + quote_requests; admin push "Gallery quote request".
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { checkRateLimit } from '../lib/rateLimit.js';

function rowToMessage(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name ?? null,
    email: row.email,
    subject: row.subject ?? null,
    message: row.message,
    userId: row.user_id ?? null,
    orderId: row.order_id?.toString?.() ?? row.order_id ?? null,
    source: row.source ?? null,
    galleryItemTitle: row.gallery_item_title ?? null,
    readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
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

  if ((req.method || '').toUpperCase() === 'GET') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(200).json([]);
    const quotesOnly = String(req.query?.quotesOnly ?? '') === '1';
    const excludeQuotes = String(req.query?.excludeQuotes ?? '') === '1';
    try {
      let rows;
      if (quotesOnly) {
        rows = await sql`
          SELECT c.id, c.name, c.email, c.subject, c.message, c.user_id, c.order_id, c.source, c.gallery_item_title, c.read_at, c.created_at
          FROM contact_messages c
          INNER JOIN quote_requests q ON q.contact_message_id = c.id
          ORDER BY c.created_at DESC
          LIMIT 500
        `;
      } else if (excludeQuotes) {
        rows = await sql`
          SELECT id, name, email, subject, message, user_id, order_id, source, gallery_item_title, read_at, created_at
          FROM contact_messages
          WHERE NOT EXISTS (SELECT 1 FROM quote_requests q WHERE q.contact_message_id = contact_messages.id)
          ORDER BY created_at DESC
          LIMIT 500
        `;
      } else {
        rows = await sql`
          SELECT id, name, email, subject, message, user_id, order_id, source, gallery_item_title, read_at, created_at
          FROM contact_messages
          ORDER BY created_at DESC
          LIMIT 500
        `;
      }
      return res.status(200).json(rows.map(rowToMessage));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[contact] GET', err);
      return res.status(500).json({ error: 'Failed to fetch messages' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    if (!checkRateLimit(req, 'contact_post', { max: 25, windowMs: 600_000 })) {
      return res.status(429).json({ error: 'Too many messages. Please try again later.' });
    }
    const body = req.body || {};
    const email = String(body.email ?? '').trim();
    const message = String(body.message ?? '').trim();
    if (!email || !message) return res.status(400).json({ error: 'Email and message are required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
    try {
      const name = body.name != null ? String(body.name).trim() : null;
      const subject = body.subject != null ? String(body.subject).trim() : null;
      const userId = body.userId != null ? String(body.userId) : null;
      const orderId = body.orderId != null && String(body.orderId).trim() !== '' ? String(body.orderId).trim() : null;
      const sourceRaw = String(body.source ?? body.messageSource ?? '').trim().toLowerCase();
      const galleryItemTitle =
        body.galleryItemTitle != null && String(body.galleryItemTitle).trim() !== ''
          ? String(body.galleryItemTitle).trim()
          : null;
      const sourceStored = sourceRaw === 'gallery_quote' ? 'gallery_quote' : null;
      const galleryTitleStored = sourceStored === 'gallery_quote' ? galleryItemTitle : null;
      const [inserted] = await sql`
        INSERT INTO contact_messages (name, email, subject, message, user_id, order_id, source, gallery_item_title)
        VALUES (${name}, ${email}, ${subject}, ${message}, ${userId}, ${orderId}, ${sourceStored}, ${galleryTitleStored})
        RETURNING id
      `;
      const messageId = inserted?.id?.toString?.() ?? null;
      if (messageId && sourceStored === 'gallery_quote') {
        try {
          await sql`
            INSERT INTO quote_requests (contact_message_id, gallery_item_title)
            VALUES (${inserted.id}, ${galleryTitleStored})
          `;
        } catch (qrErr) {
          console.error('[contact] quote_requests insert', qrErr?.message ?? qrErr);
          throw qrErr;
        }
      }
      if (messageId) {
        try {
          const adminRows = await sql`
            SELECT device_token FROM push_tokens
            WHERE is_admin = true AND device_token IS NOT NULL AND TRIM(device_token) != ''
          `;
          const tokens = (adminRows || []).map((r) => r.device_token).filter(Boolean);
          if (tokens.length) {
            const { notifyNewMessage, notifyGalleryQuoteRequest } = await import('../../api/lib/apns.js');
            if (sourceStored === 'gallery_quote') {
              const fromLine = name && name.length > 0 ? name : email;
              const designTitle =
                galleryTitleStored ||
                (subject && /^quote:\s*/i.test(subject) ? subject.replace(/^quote:\s*/i, '').trim() : null) ||
                subject ||
                'Gallery design';
              notifyGalleryQuoteRequest(tokens, messageId, fromLine, designTitle);
            } else {
              notifyNewMessage(tokens, messageId, name ?? email, subject ?? message.slice(0, 60), orderId);
            }
          }
        } catch (e) {
          console.warn('[contact] push notify', e?.message ?? e);
        }
      }
      return res.status(201).json({ ok: true });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[contact] POST', err);
      return res.status(500).json({ error: 'Failed to send message' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
