#!/usr/bin/env node
/**
 * Add bakery feature columns (orders: status, pickup_time, tip, tax; business_settings; products is_available).
 * Usage: node --env-file=.env.neon scripts/run-bakery-features-schema.js
 * Or run scripts/add-bakery-features-schema.sql in Neon SQL Editor.
 */
import { neon } from '@neondatabase/serverless';
const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  const run = async (fn, name) => {
    try {
      await fn();
      console.log(name + ' OK');
    } catch (e) {
      if (e.message && e.message.includes('already exists')) console.log(name + ' (exists)');
      else throw e;
    }
  };
  await run(() => sql`ALTER TABLE orders ADD COLUMN pickup_time TIMESTAMPTZ`, 'orders.pickup_time');
  await run(() => sql`ALTER TABLE orders ADD COLUMN ready_by TIMESTAMPTZ`, 'orders.ready_by');
  await run(() => sql`ALTER TABLE orders ADD COLUMN tip_cents INT NOT NULL DEFAULT 0`, 'orders.tip_cents');
  await run(() => sql`ALTER TABLE orders ADD COLUMN tax_cents INT NOT NULL DEFAULT 0`, 'orders.tax_cents');
  await run(() => sql`ALTER TABLE orders ADD COLUMN stripe_payment_intent_id TEXT`, 'orders.stripe_payment_intent_id');
  await run(() => sql`ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'`, 'orders.status');
  await sql`CREATE TABLE IF NOT EXISTS business_settings ( id UUID PRIMARY KEY DEFAULT gen_random_uuid(), key TEXT NOT NULL UNIQUE, value_json JSONB NOT NULL DEFAULT '{}', updated_at TIMESTAMPTZ DEFAULT NOW() )`;
  await sql`INSERT INTO business_settings (key, value_json) VALUES ('main', '{"lead_time_hours": 24, "business_hours": {"mon":"9-17","tue":"9-17","wed":"9-17","thu":"9-17","fri":"9-17","sat":"9-15","sun":null}, "min_order_cents": 0, "tax_rate_percent": 0}'::jsonb) ON CONFLICT (key) DO NOTHING`;
  await run(() => sql`ALTER TABLE products ADD COLUMN is_available BOOLEAN NOT NULL DEFAULT true`, 'products.is_available');
  await run(() => sql`ALTER TABLE products ADD COLUMN available_from DATE`, 'products.available_from');
  console.log('Bakery features schema applied.');
}

main();
