#!/usr/bin/env node
/**
 * Verifies Neon `products` table accepts INSERT/DELETE (schema matches API).
 * Usage:
 *   DATABASE_URL='postgresql://...' node scripts/smoke-product-db-write.mjs
 *   node --env-file=.env.neon scripts/smoke-product-db-write.mjs
 */
import { neon } from '@neondatabase/serverless';

const url = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!url) {
  console.error('Set POSTGRES_URL or DATABASE_URL (e.g. from Neon dashboard).');
  process.exit(1);
}

const sql = neon(url);

try {
  const rows = await sql`
    INSERT INTO products (
      name, description, price, cost, image_url, category,
      is_featured, is_sold_out, is_vegetarian, stock_quantity, low_stock_threshold
    )
    VALUES (
      'Smoke test (delete me)',
      '',
      0.01,
      NULL,
      NULL,
      'Test',
      false,
      false,
      false,
      NULL,
      NULL
    )
    RETURNING id
  `;
  const id = rows[0]?.id;
  if (!id) throw new Error('No id returned');
  await sql`DELETE FROM products WHERE id = ${id}`;
  console.log('OK: insert + delete succeeded. Schema matches API INSERT columns.');
  process.exit(0);
} catch (err) {
  console.error('FAILED:', err.message);
  if (err.code === '42703') {
    console.error('Hint: run scripts/run-missing-tables.js or ALTER TABLE for missing column (e.g. is_vegetarian).');
  }
  process.exit(1);
}
