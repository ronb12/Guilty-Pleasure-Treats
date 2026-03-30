#!/usr/bin/env node
/**
 * Set public.users.password_hash (bcrypt) for an email. Use when you changed your Neon Auth password
 * and the app still rejects login, or to align DB fallback with a known password.
 *
 *   node --env-file=.env.neon scripts/set-user-password.mjs you@example.com 'YourNewPassword'
 *
 * Requires: POSTGRES_URL or DATABASE_URL (pooled Neon URL recommended).
 */
import { neon } from '@neondatabase/serverless';
import bcrypt from 'bcryptjs';

const BCRYPT_ROUNDS = 10;
const email = (process.argv[2] || '').trim();
const plain = process.argv[3] ?? '';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL or DATABASE_URL (e.g. node --env-file=.env.neon scripts/set-user-password.mjs ...)');
  process.exit(1);
}
if (!email || !plain) {
  console.error('Usage: node scripts/set-user-password.mjs <email> <new-password>');
  process.exit(2);
}

const sql = neon(connectionString);

async function main() {
  const hash = await bcrypt.hash(plain, BCRYPT_ROUNDS);
  const rows = await sql`
    UPDATE users
    SET password_hash = ${hash}, updated_at = NOW()
    WHERE LOWER(TRIM(COALESCE(email, ''))) = ${email.toLowerCase()}
    RETURNING id, email
  `;
  const list = Array.isArray(rows) ? rows : [];
  if (list.length === 0) {
    console.error('No user found with that email.');
    process.exit(1);
  }
  console.log('Updated password_hash for:', list[0].email, '(' + list[0].id + ')');
}

main().catch((e) => {
  console.error(e?.message ?? e);
  process.exit(1);
});
