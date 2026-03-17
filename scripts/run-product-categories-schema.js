#!/usr/bin/env node
/**
 * Create product_categories table in Neon. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.production scripts/run-product-categories-schema.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.production --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    await sql`
      CREATE TABLE IF NOT EXISTS product_categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL UNIQUE,
        display_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_product_categories_display_order ON product_categories(display_order ASC, name ASC)`;
    const existing = await sql`SELECT 1 FROM product_categories LIMIT 1`;
    if (existing.length === 0) {
      await sql`INSERT INTO product_categories (name, display_order) VALUES ('Cupcakes', 0), ('Cookies', 1), ('Cakes', 2), ('Brownies', 3), ('Seasonal Treats', 4) ON CONFLICT (name) DO NOTHING`;
      console.log('Seeded default categories.');
    }
    console.log('product_categories table ready.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
