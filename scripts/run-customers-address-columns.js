#!/usr/bin/env node
/**
 * Add structured address columns to customers table. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.neon scripts/run-customers-address-columns.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS street TEXT`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS address_line_2 TEXT`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS city TEXT`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS state TEXT`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS postal_code TEXT`;
    console.log('customers address columns added.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
