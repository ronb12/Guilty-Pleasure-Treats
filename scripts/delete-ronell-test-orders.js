#!/usr/bin/env node
/**
 * Remove all orders and custom cake orders for user ronellbradley@hotmail.com (test orders).
 * Usage: node --env-file=.env.neon scripts/delete-ronell-test-orders.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);
const RONELL_EMAIL = 'ronellbradley@hotmail.com';

async function main() {
  try {
    const users = await sql`
      SELECT id FROM users WHERE LOWER(TRIM(email)) = ${RONELL_EMAIL.toLowerCase()}
    `;
    if (users.length === 0) {
      console.log('No user found with email', RONELL_EMAIL);
      process.exit(0);
    }
    const userId = users[0].id;

    const customDeleted = await sql`
      DELETE FROM custom_cake_orders WHERE user_id = ${userId} RETURNING id
    `;
    const ordersDeleted = await sql`
      DELETE FROM orders WHERE user_id = ${userId} RETURNING id
    `;

    console.log('Deleted orders for', RONELL_EMAIL + ':');
    console.log('  orders:', Array.isArray(ordersDeleted) ? ordersDeleted.length : 0);
    console.log('  custom_cake_orders:', Array.isArray(customDeleted) ? customDeleted.length : 0);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
