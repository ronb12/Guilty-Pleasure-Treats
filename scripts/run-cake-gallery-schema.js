#!/usr/bin/env node
/**
 * Create cake_gallery table in Neon. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.production scripts/run-cake-gallery-schema.js
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
      CREATE TABLE IF NOT EXISTS cake_gallery (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        image_url TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        description TEXT,
        category TEXT,
        price DECIMAL(10,2),
        display_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`ALTER TABLE cake_gallery ADD COLUMN IF NOT EXISTS category TEXT`;
    await sql`CREATE INDEX IF NOT EXISTS idx_cake_gallery_display_order ON cake_gallery(display_order ASC, created_at DESC)`;
    console.log('cake_gallery table and index created.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
