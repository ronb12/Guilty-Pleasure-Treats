#!/usr/bin/env node
/**
 * Remove test orders by customer name: Ronell, Ron12, Ronell Bradley.
 * Usage: node --env-file=.env.neon scripts/delete-test-orders-by-name.js
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
    // Find order ids where customer name matches (case-insensitive, trimmed)
    const ordersToDelete = await sql`
      SELECT id, user_id, customer_name, created_at
      FROM orders
      WHERE LOWER(TRIM(customer_name)) IN (${'ronell'}, ${'ron12'}, ${'ronell bradley'})
    `;
    if (ordersToDelete.length === 0) {
      console.log('No orders found for customer names: Ronell, Ron12, Ronell Bradley');
      process.exit(0);
    }
    const orderIds = ordersToDelete.map((r) => r.id);
    console.log('Found', orderIds.length, 'order(s):', ordersToDelete.map((r) => r.customer_name + ' (' + r.created_at + ')').join(', '));

    let customCount = 0;
    // Delete custom_cake_orders linked to these orders (by order_id)
    for (const oid of orderIds) {
      const r = await sql`DELETE FROM custom_cake_orders WHERE order_id = ${oid} RETURNING id`;
      customCount += Array.isArray(r) ? r.length : 0;
    }
    // Also delete custom_cake_orders by same user_ids (in case not linked by order_id)
    const userIds = [...new Set(ordersToDelete.map((r) => r.user_id).filter(Boolean))];
    for (const uid of userIds) {
      const r = await sql`DELETE FROM custom_cake_orders WHERE user_id = ${uid} RETURNING id`;
      customCount += Array.isArray(r) ? r.length : 0;
    }

    // Delete the orders
    let ordersCount = 0;
    for (const oid of orderIds) {
      const r = await sql`DELETE FROM orders WHERE id = ${oid} RETURNING id`;
      ordersCount += Array.isArray(r) ? r.length : 0;
    }

    console.log('Deleted:');
    console.log('  orders:', ordersCount);
    console.log('  custom_cake_orders:', customCount);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
