#!/usr/bin/env node
/**
 * Run contact_messages schema against Neon. Requires POSTGRES_URL.
 * Usage: POSTGRES_URL="postgresql://..." node scripts/run-contact-schema.js
 * Or: vercel env pull .env.local && node -r dotenv/config scripts/run-contact-schema.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL (or DATABASE_URL) with your Neon connection string.');
  console.error('Get it from: Neon Console → your branch → Connection details');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    await sql`
      CREATE TABLE IF NOT EXISTS contact_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT,
        email TEXT NOT NULL,
        subject TEXT,
        message TEXT NOT NULL,
        user_id TEXT,
        read_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON contact_messages(created_at DESC)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_messages_read_at ON contact_messages(read_at) WHERE read_at IS NULL`;
    console.log('contact_messages table and indexes created.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
