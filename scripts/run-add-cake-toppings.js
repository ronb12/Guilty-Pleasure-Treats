#!/usr/bin/env node
/**
 * Create cake_toppings table and seed default toppings so Admin → Cake Options shows them.
 * Usage: node --env-file=.env.neon scripts/run-add-cake-toppings.js
 * Or:   POSTGRES_URL='...' node scripts/run-add-cake-toppings.js
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
    await sql`
      CREATE TABLE IF NOT EXISTS cake_toppings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        label TEXT NOT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    const existing = await sql`SELECT 1 FROM cake_toppings LIMIT 1`;
    if (existing.length === 0) {
      const labels = [
        'Sprinkles', 'Fresh fruit', 'Chocolate drizzle', 'Fresh berries', 'Whipped cream',
        'Caramel drizzle', 'Toasted nuts', 'Coconut', 'Candy pieces', 'Edible flowers', 'Gold dust',
      ];
      for (let i = 0; i < labels.length; i++) {
        await sql`INSERT INTO cake_toppings (label, sort_order) VALUES (${labels[i]}, ${i})`;
      }
      console.log('cake_toppings table created and seeded with', labels.length, 'toppings.');
    } else {
      console.log('cake_toppings table already has data; no seed applied.');
    }
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
