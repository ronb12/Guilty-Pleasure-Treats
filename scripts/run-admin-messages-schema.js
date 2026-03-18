#!/usr/bin/env node
/**
 * Create admin_messages table in Neon (for Admin → Messages “Send new message” / Sent list).
 * Usage: node --env-file=.env.neon scripts/run-admin-messages-schema.js
 * Or:   POSTGRES_URL='...' node scripts/run-admin-messages-schema.js
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
      CREATE TABLE IF NOT EXISTS admin_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        to_user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_admin_messages_created_at ON admin_messages(created_at DESC)`;
    console.log('admin_messages table is ready.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
