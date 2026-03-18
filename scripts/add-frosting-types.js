#!/usr/bin/env node
/**
 * Add more frosting types to Neon (only inserts labels that don't already exist).
 * Usage: node --env-file=.env.neon scripts/add-frosting-types.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

const NEW_FROSTINGS = [
  'Strawberry',
  'Lemon',
  'Salted Caramel',
  'Peanut Butter',
  'Mocha',
];

async function main() {
  try {
    const existing = await sql`SELECT label FROM frosting_types`;
    const existingSet = new Set(existing.map((r) => r.label));
    let added = 0;
    const maxOrder = await sql`SELECT COALESCE(MAX(sort_order), -1) AS m FROM frosting_types`;
    let nextOrder = Number(maxOrder[0]?.m ?? -1) + 1;
    for (const label of NEW_FROSTINGS) {
      if (existingSet.has(label)) continue;
      await sql`INSERT INTO frosting_types (label, sort_order) VALUES (${label}, ${nextOrder})`;
      nextOrder += 1;
      added += 1;
      console.log('Added:', label);
    }
    console.log(added === 0 ? 'No new frostings (all already exist).' : `Added ${added} frosting type(s).`);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
