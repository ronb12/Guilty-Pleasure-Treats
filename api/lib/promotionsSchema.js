/**
 * Align legacy `promotions` rows with APIs that expect reward-rule columns.
 * Safe no-ops when columns already exist. Ignores 42P01 if the table is missing.
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 */
export async function ensurePromotionsOptionalColumns(sql) {
  if (!sql) return;
  try {
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_subtotal DECIMAL(10,2)`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_total_quantity INTEGER`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT false`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS product_id TEXT`;
  } catch (e) {
    if (e?.code === '42P01') return;
    throw e;
  }
}
