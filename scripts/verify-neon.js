#!/usr/bin/env node
/**
 * Verify Neon database has all required tables and columns.
 * Usage: POSTGRES_URL='...' node scripts/verify-neon.js
 */
import pg from 'pg';

const REQUIRED_TABLES = [
  'ai_cake_designs',
  'business_settings',
  'cake_flavors',
  'cake_sizes',
  'custom_cake_orders',
  'frosting_types',
  'orders',
  'products',
  'promotions',
  'sessions',
  'users',
];

const REQUIRED_PRODUCT_COLUMNS = [
  'id', 'name', 'description', 'price', 'image_url', 'category',
  'is_featured', 'is_sold_out', 'is_vegetarian', 'stock_quantity', 'low_stock_threshold',
  'created_at', 'updated_at',
];

async function main() {
  const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('Set POSTGRES_URL or DATABASE_URL to verify the database.');
    console.error('Example: POSTGRES_URL="postgresql://..." node scripts/verify-neon.js');
    process.exit(1);
  }

  const client = new pg.Client({ connectionString });
  await client.connect();

  try {
    const tablesRes = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);
    const existingTables = tablesRes.rows.map((r) => r.table_name);

    const missingTables = REQUIRED_TABLES.filter((t) => !existingTables.includes(t));
    if (missingTables.length) {
      console.error('Missing tables:', missingTables.join(', '));
      console.error('Run api/schema.sql or api/migrate-neon.sql in Neon SQL Editor.');
      process.exit(1);
    }
    console.log('Tables OK:', existingTables.join(', '));

    const colsRes = await client.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'products'
      ORDER BY ordinal_position
    `);
    const productColumns = colsRes.rows.map((r) => r.column_name);
    const missingCols = REQUIRED_PRODUCT_COLUMNS.filter((c) => !productColumns.includes(c));
    if (missingCols.length) {
      console.error('products table missing columns:', missingCols.join(', '));
      console.error('Run api/migrate-neon.sql to add is_vegetarian and any others.');
      process.exit(1);
    }
    console.log('products columns OK (including is_vegetarian)');

    const businessRes = await client.query(`SELECT id FROM business_settings WHERE id = 'business' LIMIT 1`);
    if (businessRes.rows.length === 0) {
      console.warn('Warning: business_settings has no row. Run api/schema.sql to seed.');
    } else {
      console.log('business_settings row OK');
    }

    const cakeSizesRes = await client.query(`SELECT COUNT(*) AS n FROM cake_sizes`);
    const cakeSizesCount = parseInt(cakeSizesRes.rows[0]?.n ?? '0', 10);
    if (cakeSizesCount === 0) {
      console.warn('Warning: cake_sizes is empty. Run api/schema.sql or api/migrate-neon.sql to seed.');
    } else {
      console.log('cake_sizes seeded OK (' + cakeSizesCount + ' rows)');
    }

    console.log('\nDatabase is fully set up.');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
