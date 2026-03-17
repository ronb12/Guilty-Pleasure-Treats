#!/usr/bin/env node
/**
 * Create push_tokens table in Neon. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.neon scripts/run-push-tokens-schema.js
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
      CREATE TABLE IF NOT EXISTS push_tokens (
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device_token TEXT NOT NULL,
        is_admin BOOLEAN NOT NULL DEFAULT false,
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (user_id)
      )
    `;
    await sql`ALTER TABLE push_tokens ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false`;
    await sql`CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at)`;
    console.log('push_tokens table ready.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
