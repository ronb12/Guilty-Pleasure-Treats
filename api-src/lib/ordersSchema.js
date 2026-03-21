/**
 * Legacy `orders` rows may lack columns added for analytics / checkout.
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 */
export async function ensureOrdersOptionalColumns(sql) {
  if (!sql) return;
  try {
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0`;
  } catch (e) {
    if (e?.code === '42P01') return;
    throw e;
  }
}
