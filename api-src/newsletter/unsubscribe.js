/**
 * GET /api/newsletter/unsubscribe?token=… — one-click marketing opt-out (no auth).
 * Inserts into newsletter_suppressions and clears preference for matching users row if any.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { ensureNewsletterSuppressionsTable } from '../../api/lib/newsletterSuppressions.js';
import {
  parseUnsubscribeToken,
  getNewsletterUnsubscribeSecret,
} from '../../api/lib/newsletterUnsubscribeToken.js';

function htmlPage(title, message) {
  const esc = (s) =>
    String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>${esc(
    title,
  )}</title><style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#fdf2f8;margin:0;padding:32px 16px;color:#3d2129;}main{max-width:480px;margin:0 auto;background:#fff;padding:28px;border-radius:12px;border:1px solid #f5d0e4;}h1{font-size:1.25rem;margin:0 0 12px;}p{margin:0;line-height:1.5;font-size:15px;}</style></head><body><main><h1>${esc(
    title,
  )}</h1><p>${message}</p></main></body></html>`;
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if ((req.method || '').toUpperCase() !== 'GET') {
    res.setHeader('Content-Type', 'application/json');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!hasDb() || !sql) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res
      .status(503)
      .send(htmlPage('Unavailable', 'This service is temporarily unavailable. Please try again later or contact the bakery.'));
  }

  const secret = getNewsletterUnsubscribeSecret();
  const rawTok = req.query?.token != null ? String(req.query.token) : '';
  const email = parseUnsubscribeToken(rawTok, secret);

  if (!secret || !email) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res
      .status(400)
      .send(
        htmlPage(
          'Link not valid',
          'This unsubscribe link is invalid or has expired. You can turn off marketing emails in the app under Settings, or reply to the bakery for help.',
        ),
      );
  }

  try {
    await ensureNewsletterSuppressionsTable(sql);
    await sql`
      INSERT INTO newsletter_suppressions (email)
      VALUES (${email})
      ON CONFLICT (email) DO NOTHING
    `;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res
      .status(200)
      .send(
        htmlPage(
          'You’re unsubscribed',
          'You won’t receive marketing emails from us anymore. You may still get messages about orders you place. You can re-enable newsletters anytime in the app under Settings.',
        ),
      );
  } catch (err) {
    console.error('[newsletter/unsubscribe]', err);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res
      .status(500)
      .send(htmlPage('Something went wrong', 'Please try again later or contact the bakery.'));
  }
}
