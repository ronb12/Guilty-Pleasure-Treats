/**
 * Align legacy `promotions` rows with APIs that expect reward-rule columns.
 * Safe no-ops when columns already exist. Ignores 42P01 if the table is missing.
 * Per serverless instance: run at most once (reduces Neon round-trips on burst traffic).
 * @param {(strings: TemplateStringsArray, ...values: unknown[]) => Promise<unknown>} sql
 */
const promotionsSchemaKey = '__gpt_promotions_optional_columns_ok';

export async function ensurePromotionsOptionalColumns(sql) {
  if (!sql) return;
  if (globalThis[promotionsSchemaKey]) return;
  try {
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_subtotal DECIMAL(10,2)`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_total_quantity INTEGER`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT false`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS product_id TEXT`;
    globalThis[promotionsSchemaKey] = true;
  } catch (e) {
    if (e?.code === '42P01') {
      globalThis[promotionsSchemaKey] = true;
      return;
    }
    throw e;
  }
}
