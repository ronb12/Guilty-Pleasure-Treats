#!/usr/bin/env node
/** List recent orders from Neon. Usage: node --env-file=.env.neon scripts/list-orders.js */
import { neon } from '@neondatabase/serverless';
const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) { console.error('Set POSTGRES_URL'); process.exit(1); }
const sql = neon(connectionString);
const rows = await sql`SELECT id, customer_name, total, status, created_at FROM orders ORDER BY created_at DESC LIMIT 20`;
console.log(JSON.stringify(rows, null, 2));
