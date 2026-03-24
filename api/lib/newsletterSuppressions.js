/**
 * Marketing email opt-out: suppressed addresses are excluded from /api/admin/newsletter sends.
 */

export function normalizeMarketingEmail(email) {
  const e = String(email ?? '')
    .trim()
    .toLowerCase();
  return e || null;
}

export async function ensureNewsletterSuppressionsTable(sql) {
  await sql`
    CREATE TABLE IF NOT EXISTS newsletter_suppressions (
      email TEXT PRIMARY KEY,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `;
}
