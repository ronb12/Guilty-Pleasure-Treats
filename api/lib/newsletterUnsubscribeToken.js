/**
 * Signed unsubscribe links for newsletter emails (HMAC over normalized email).
 * Env: NEWSLETTER_UNSUBSCRIBE_SECRET (recommended), or falls back to RESEND_API_KEY.
 * NEWSLETTER_PUBLIC_BASE_URL or PUBLIC_APP_URL, else https://$VERCEL_URL
 */
import crypto from 'crypto';
import { normalizeMarketingEmail } from './newsletterSuppressions.js';

export function getNewsletterUnsubscribeSecret() {
  return (
    process.env.NEWSLETTER_UNSUBSCRIBE_SECRET ||
    process.env.RESEND_API_KEY ||
    ''
  ).trim();
}

export function buildPublicBaseUrl() {
  const explicit = (process.env.NEWSLETTER_PUBLIC_BASE_URL || process.env.PUBLIC_APP_URL || '')
    .trim()
    .replace(/\/$/, '');
  if (explicit) return explicit;
  const v = (process.env.VERCEL_URL || '').trim().replace(/\/$/, '');
  if (v) return `https://${v}`;
  return '';
}

export function makeUnsubscribeToken(email, secret) {
  const e = normalizeMarketingEmail(email);
  if (!e || !secret) return null;
  const payload = Buffer.from(e, 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', secret).update(e).digest('base64url');
  return `${payload}.${sig}`;
}

export function parseUnsubscribeToken(token, secret) {
  if (!token || !secret) return null;
  const parts = String(token).split('.');
  if (parts.length !== 2) return null;
  let e;
  try {
    e = Buffer.from(parts[0], 'base64url').toString('utf8');
  } catch {
    return null;
  }
  e = normalizeMarketingEmail(e);
  if (!e) return null;
  const sig = crypto.createHmac('sha256', secret).update(e).digest('base64url');
  if (sig !== parts[1]) return null;
  return e;
}

export function buildUnsubscribeUrl(email) {
  const secret = getNewsletterUnsubscribeSecret();
  const base = buildPublicBaseUrl();
  const tok = makeUnsubscribeToken(email, secret);
  if (!base || !tok) return null;
  return `${base}/api/newsletter/unsubscribe?token=${encodeURIComponent(tok)}`;
}

/**
 * Replace {{UNSUBSCRIBE_URL}} in HTML/text; build plain-text part with unsubscribe line if no text body was sent.
 */
export function injectNewsletterUnsubscribe(html, text, email) {
  const url = buildUnsubscribeUrl(email);
  const placeholder = '{{UNSUBSCRIBE_URL}}';
  let htmlOut = String(html || '');
  const hadText = text != null && String(text).trim() !== '';
  let textOut = hadText ? String(text) : null;

  if (!url) {
    htmlOut = htmlOut.split(placeholder).join('#');
    if (textOut != null) textOut = textOut.split(placeholder).join('');
    return { html: htmlOut, text: textOut ?? undefined };
  }

  htmlOut = htmlOut.split(placeholder).join(url);
  if (textOut != null) {
    textOut = textOut.split(placeholder).join(url);
  } else {
    const stripped = stripHtmlSimple(htmlOut);
    textOut = stripped ? `${stripped}\n\nUnsubscribe: ${url}` : `Unsubscribe: ${url}`;
  }
  return { html: htmlOut, text: textOut };
}

function stripHtmlSimple(html) {
  return String(html)
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
