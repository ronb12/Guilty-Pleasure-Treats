/**
 * Legacy `orders` rows may lack columns added for analytics / checkout.
 * @param {(strings: TemplateStringsArray, ...values: unknown[]) => Promise<unknown>} sql
 */
export async function ensureOrdersOptionalColumns(sql) {
  if (!sql) return;
  const alters = [
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_carrier TEXT`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number TEXT`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_status_detail TEXT`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_updated_at TIMESTAMPTZ`,
  ];
  for (const run of alters) {
    try {
      await run();
    } catch (e) {
      if (e?.code === '42P01') return;
      // Read-only or other DDL failures: log and continue; GET uses legacy SELECT fallback.
      console.warn('[ordersSchema] optional column ALTER skipped:', e?.code, e?.message);
    }
  }
}
