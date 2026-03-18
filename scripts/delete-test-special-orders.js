#!/usr/bin/env node
/**
 * Remove test special orders from Neon:
 * - Gallery orders: ai_cake_designs where price = 1 or design_prompt = 'Test'
 * - Custom cake orders from test date 3/17/26 (optional)
 * Usage: node --env-file=.env.neon scripts/delete-test-special-orders.js
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
    // 1. Delete gallery (AI cake design) test orders: $1.00 or design_prompt 'Test'
    const galleryDeleted = await sql`
      DELETE FROM ai_cake_designs
      WHERE price = 1 OR LOWER(TRIM(design_prompt)) = 'test'
      RETURNING id
    `;
    const galleryCount = Array.isArray(galleryDeleted) ? galleryDeleted.length : 0;
    console.log('Deleted gallery (AI cake design) test orders:', galleryCount);

    // 2. Delete custom cake orders from 2026-03-17 (test date from screenshot)
    const cakeDeleted = await sql`
      DELETE FROM custom_cake_orders
      WHERE created_at::date = '2026-03-17'
      RETURNING id
    `;
    const cakeCount = Array.isArray(cakeDeleted) ? cakeDeleted.length : 0;
    console.log('Deleted custom cake orders from 3/17/26:', cakeCount);

    console.log('Done. Refresh Admin → Orders to see the update.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
