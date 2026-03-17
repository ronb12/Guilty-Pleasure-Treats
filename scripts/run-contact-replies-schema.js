#!/usr/bin/env node
/**
 * Run contact_message_replies schema against Neon. Requires POSTGRES_URL.
 * Usage:
 *   vercel env pull .env.local && node scripts/run-contact-replies-schema.js
 * Or: POSTGRES_URL="postgresql://..." node scripts/run-contact-replies-schema.js
 */
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { neon } from '@neondatabase/serverless';

// Load .env.local if present (no dotenv package needed)
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, '..', '.env.local');
if (existsSync(envPath)) {
  const content = readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const idx = line.indexOf('=');
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(key) && !process.env[key]) process.env[key] = value;
  }
}

const connectionString =
  process.env.POSTGRES_URL ||
  process.env.DATABASE_URL ||
  process.env.NEON_DATABASE_URL;
if (!connectionString || !connectionString.startsWith('postgres')) {
  console.error('Missing Postgres connection string. Use one of:');
  console.error('  • Add POSTGRES_URL in Vercel: Project → Settings → Environment Variables');
  console.error('    Then run: vercel env pull .env.local');
  console.error('  • Or pull production env: vercel env pull .env.local --environment=production');
  console.error('  • Or run: POSTGRES_URL="postgresql://user:pass@host/db?sslmode=require" node scripts/run-contact-replies-schema.js');
  console.error('  Get the URL from: Neon Console → your project → Connection details');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    await sql`
      CREATE TABLE IF NOT EXISTS contact_message_replies (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        contact_message_id UUID NOT NULL REFERENCES contact_messages(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_message_replies_message_id ON contact_message_replies(contact_message_id)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_message_replies_created_at ON contact_message_replies(created_at DESC)`;
    console.log('contact_message_replies table and indexes created.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
