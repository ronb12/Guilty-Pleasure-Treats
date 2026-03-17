#!/usr/bin/env node
/**
 * Fix users whose password_hash is stored as plain text (no bcrypt).
 * We treat the current value as the plain password, hash it with bcrypt, and update.
 * Usage: node --env-file=.env.neon scripts/fix-plaintext-passwords.js
 */
import { neon } from '@neondatabase/serverless';
import bcrypt from 'bcryptjs';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    // Find users where password_hash doesn't look like bcrypt (bcrypt starts with $2a$ or $2b$)
    const rows = await sql`
      SELECT id, email, display_name, password_hash
      FROM users
      WHERE password_hash IS NOT NULL
        AND TRIM(password_hash) != ''
        AND password_hash NOT LIKE '$2%'
    `;

    if (rows.length === 0) {
      console.log('No users with plain-text passwords found. All password_hash values look like bcrypt.');
      return;
    }

    console.log('Found', rows.length, 'user(s) with non-bcrypt password_hash. Hashing and updating...\n');

    for (const user of rows) {
      const plainPassword = String(user.password_hash).trim();
      const hash = await bcrypt.hash(plainPassword, 10);
      await sql`
        UPDATE users SET password_hash = ${hash} WHERE id = ${user.id}
      `;
      console.log('Updated:', user.email, '(display_name:', user.display_name + ')');
      console.log('  They can still sign in with the same password.\n');
    }

    console.log('Done. Those users can sign in with their existing passwords.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
