#!/usr/bin/env node
/**
 * Confirm cake options data exists in Neon (cake_sizes, cake_flavors, frosting_types, cake_toppings).
 * Usage: node --env-file=.env.neon scripts/check-cake-options.js
 * Or:   POSTGRES_URL='...' node scripts/check-cake-options.js
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
    const [sizes, flavors, frostings, toppings] = await Promise.all([
      sql`SELECT id, label, price, sort_order FROM cake_sizes ORDER BY sort_order ASC, label ASC`,
      sql`SELECT id, label, sort_order FROM cake_flavors ORDER BY sort_order ASC, label ASC`,
      sql`SELECT id, label, sort_order FROM frosting_types ORDER BY sort_order ASC, label ASC`,
      sql`SELECT id, label, sort_order FROM cake_toppings ORDER BY sort_order ASC, label ASC`,
    ]);

    console.log('--- Cake options in Neon ---\n');
    console.log('cake_sizes:', sizes.length, 'rows');
    sizes.forEach((r) => console.log('  ', r.label, '-', Number(r.price).toFixed(2)));
    console.log('\ncake_flavors:', flavors.length, 'rows');
    flavors.forEach((r) => console.log('  ', r.label));
    console.log('\nfrosting_types:', frostings.length, 'rows');
    frostings.forEach((r) => console.log('  ', r.label));
    console.log('\ncake_toppings:', toppings.length, 'rows');
    toppings.forEach((r) => console.log('  ', r.label));
    console.log('\n--- Done ---');
  } catch (err) {
    console.error('Error:', err.message);
    if (err.message?.includes('relation') && err.message?.includes('does not exist')) {
      console.error('Run api/schema.sql in Neon SQL Editor (or run migrations) to create the tables.');
    }
    process.exit(1);
  }
}

main();
