#!/usr/bin/env node
/**
 * Create customers table in Neon. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.production scripts/run-customers-schema.js
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
      CREATE TABLE IF NOT EXISTS customers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS address TEXT`;
    console.log('customers table ready.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
