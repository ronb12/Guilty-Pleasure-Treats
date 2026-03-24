/**
 * GET /api/admin/newsletter — recipient count (admin).
 * POST /api/admin/newsletter — send newsletter (admin). Body: subject, htmlBody?, textBody?, replyTo?
 *
 * Recipients: distinct emails from orders (guest + signed-in) UNION non-admin user accounts.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { sendNewsletterToRecipients } from '../../api/lib/resendEmail.js';
import { ensureNewsletterSuppressionsTable } from '../../api/lib/newsletterSuppressions.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (session.isAdmin !== true) return res.status(403).json({ error: 'Admin required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      await ensureNewsletterSuppressionsTable(sql);
      const [row] = await sql`
        SELECT COUNT(*)::int AS c FROM (
          SELECT DISTINCT LOWER(TRIM(o.customer_email)) AS email
          FROM orders o
          WHERE o.customer_email IS NOT NULL AND TRIM(o.customer_email) <> ''
          UNION
          SELECT DISTINCT LOWER(TRIM(u.email)) AS email
          FROM users u
          WHERE u.email IS NOT NULL AND TRIM(u.email) <> ''
            AND COALESCE(u.is_admin, false) = false
        ) AS sub
        WHERE email IS NOT NULL AND TRIM(email) <> ''
          AND NOT EXISTS (
            SELECT 1 FROM newsletter_suppressions ns WHERE ns.email = sub.email
          )
      `;
      const recipientCount = Number(row?.c ?? 0);
      return res.status(200).json({ recipientCount });
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json({ recipientCount: 0 });
      console.error('[admin/newsletter] GET', err);
      return res.status(500).json({ error: 'Failed to count recipients' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const body = req.body || {};
    const subject = String(body.subject ?? '').trim();
    const htmlBody = body.htmlBody != null ? String(body.htmlBody) : '';
    const textBody = body.textBody != null ? String(body.textBody).trim() : '';
    if (!subject) return res.status(400).json({ error: 'subject is required' });
    if (!htmlBody.trim() && !textBody) {
      return res.status(400).json({ error: 'htmlBody or textBody is required' });
    }

    try {
      await ensureNewsletterSuppressionsTable(sql);
      const rows = await sql`
        SELECT email FROM (
          SELECT DISTINCT LOWER(TRIM(o.customer_email)) AS email
          FROM orders o
          WHERE o.customer_email IS NOT NULL AND TRIM(o.customer_email) <> ''
          UNION
          SELECT DISTINCT LOWER(TRIM(u.email)) AS email
          FROM users u
          WHERE u.email IS NOT NULL AND TRIM(u.email) <> ''
            AND COALESCE(u.is_admin, false) = false
        ) AS sub
        WHERE email IS NOT NULL AND TRIM(email) <> ''
          AND NOT EXISTS (
            SELECT 1 FROM newsletter_suppressions ns WHERE ns.email = sub.email
          )
      `;
      const list = (rows || []).map((r) => r.email).filter(Boolean);
      if (list.length === 0) {
        return res.status(400).json({ error: 'No recipient email addresses. Add emails via orders (checkout) or customer accounts.' });
      }
      let replyTo = body.replyTo != null ? String(body.replyTo).trim() : '';
      if (!replyTo) {
        try {
          const [settingsRow] = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
          const v = settingsRow?.value_json ?? {};
          replyTo = String(v.contact_email ?? v.contactEmail ?? '').trim();
        } catch {
          replyTo = '';
        }
      }
      const maxSends = Math.min(500, Math.max(1, Number(process.env.NEWSLETTER_MAX_SENDS) || 150));
      const result = await sendNewsletterToRecipients(list, {
        subject,
        html: htmlBody.trim() ? htmlBody : undefined,
        text: textBody || undefined,
        replyTo: replyTo || undefined,
        maxSends,
      });
      return res.status(200).json(result);
    } catch (err) {
      if (err?.statusCode === 503) {
        return res.status(503).json({ error: err.message });
      }
      console.error('[admin/newsletter] POST', err);
      return res.status(500).json({ error: err?.message || 'Failed to send newsletter' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
