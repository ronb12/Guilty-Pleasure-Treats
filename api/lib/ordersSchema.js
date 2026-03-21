/**
 * Legacy `orders` rows may lack columns added for analytics / checkout.
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 */
export async function ensureOrdersOptionalColumns(sql) {
  if (!sql) return;
  const alters = [
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT`,
    () => sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0`,
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
