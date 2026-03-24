/**
 * Resend API (https://resend.com) for transactional / newsletter email.
 * Env: RESEND_API_KEY, NEWSLETTER_FROM_EMAIL or RESEND_FROM_EMAIL (verified domain).
 * Optional: NEWSLETTER_MAX_SENDS (default 150) — max recipients per request (Vercel timeout).
 */

function stripHtml(html) {
  if (!html) return '';
  return String(html)
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function sendResendEmail({ to, subject, html, text, replyTo }) {
  const key = process.env.RESEND_API_KEY;
  if (!key) {
    const e = new Error('Email sending is not configured. Set RESEND_API_KEY in Vercel.');
    e.statusCode = 503;
    throw e;
  }
  const from = process.env.NEWSLETTER_FROM_EMAIL || process.env.RESEND_FROM_EMAIL;
  if (!from) {
    const e = new Error(
      'Set NEWSLETTER_FROM_EMAIL or RESEND_FROM_EMAIL to a verified sender domain in Resend.',
    );
    e.statusCode = 503;
    throw e;
  }
  const textBody = text || stripHtml(html) || 'Message from Guilty Pleasure Treats';
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject,
      html: html || undefined,
      text: textBody,
      reply_to: replyTo || undefined,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const e = new Error(data?.message || `Resend error ${res.status}`);
    e.statusCode = res.status;
    throw e;
  }
  return data;
}

const DEFAULT_MAX = 150;

/** Fail fast before looping when env is missing (avoids N failed attempts). */
function assertResendConfiguredForBatch() {
  const key = process.env.RESEND_API_KEY;
  if (!key) {
    const e = new Error('Email sending is not configured. Set RESEND_API_KEY in Vercel.');
    e.statusCode = 503;
    throw e;
  }
  const from = process.env.NEWSLETTER_FROM_EMAIL || process.env.RESEND_FROM_EMAIL;
  if (!from) {
    const e = new Error(
      'Set NEWSLETTER_FROM_EMAIL or RESEND_FROM_EMAIL to a verified sender domain in Resend.',
    );
    e.statusCode = 503;
    throw e;
  }
}

/**
 * @param {string[]} recipients
 * @param {{ subject: string, html?: string, text?: string, replyTo?: string, maxSends?: number }} opts
 */
export async function sendNewsletterToRecipients(recipients, opts) {
  assertResendConfiguredForBatch();
  const { subject, html, text, replyTo, maxSends = DEFAULT_MAX } = opts;
  const envMax = Number(process.env.NEWSLETTER_MAX_SENDS);
  const cap = Number.isFinite(envMax) && envMax > 0 ? Math.min(500, envMax) : maxSends;
  const unique = [
    ...new Set(
      recipients
        .map((e) => String(e).trim().toLowerCase())
        .filter((e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)),
    ),
  ];
  const capped = unique.slice(0, cap);
  let sent = 0;
  let failed = 0;
  const sampleErrors = [];
  for (const to of capped) {
    try {
      await sendResendEmail({ to, subject, html, text, replyTo });
      sent += 1;
    } catch (err) {
      failed += 1;
      if (sampleErrors.length < 5) {
        sampleErrors.push({ to, message: err?.message ?? String(err) });
      }
    }
  }
  return {
    sent,
    failed,
    total: unique.length,
    attempted: capped.length,
    truncated: unique.length > cap,
    sampleErrors,
  };
}
