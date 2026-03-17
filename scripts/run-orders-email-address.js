#!/usr/bin/env node
/**
 * Add customer_email and delivery_address to orders table. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.neon scripts/run-orders-email-address.js
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
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_email TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_address TEXT`;
    console.log('orders customer_email and delivery_address columns added.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
