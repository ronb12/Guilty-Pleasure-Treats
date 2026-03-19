/**
 * Database access for Vercel serverless. Uses Neon serverless driver.
 * Set DATABASE_URL or POSTGRES_URL in Vercel env.
 */
const { neon } = require('@neondatabase/serverless');

const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;
if (!connectionString) {
  console.warn('Missing DATABASE_URL/POSTGRES_URL; DB calls will fail.');
}

const sql = connectionString ? neon(connectionString) : null;

/** Run a query. Returns empty array if no DB URL. */
async function query(...args) {
  if (!sql) return [];
  return sql(...args);
}

// Tagged template for sql`SELECT ...`. When no DB URL, return empty array.
const sqlTag = sql || (async function noop() { return []; });
module.exports = { sql: sqlTag, query };
