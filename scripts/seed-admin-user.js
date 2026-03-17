#!/usr/bin/env node
/**
 * Seed admin user: ronellbradley@hotmail.com / password1234
 * Usage:
 *   POSTGRES_URL='...' node scripts/seed-admin-user.js   -- insert into Neon
 *   node scripts/seed-admin-user.js                       -- print SQL to run in Neon
 */
import bcrypt from 'bcryptjs';
import pg from 'pg';

const ADMIN_EMAIL = 'ronellbradley@hotmail.com';
const ADMIN_PASSWORD = 'password1234';
const BCRYPT_ROUNDS = 10;

async function main() {
  const hash = await bcrypt.hash(ADMIN_PASSWORD, BCRYPT_ROUNDS);
  const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;

  const sql = `INSERT INTO users (email, display_name, password_hash, is_admin, points)
VALUES ('${ADMIN_EMAIL}', 'Admin', '${hash}', true, 0)
ON CONFLICT (email) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  is_admin = true,
  display_name = COALESCE(EXCLUDED.display_name, users.display_name);`;

  if (connectionString) {
    const client = new pg.Client({ connectionString });
    await client.connect();
    try {
      await client.query(sql);
      console.log('Admin user created/updated:', ADMIN_EMAIL);
      console.log('You can sign in with that email and password:', ADMIN_PASSWORD);
    } finally {
      await client.end();
    }
  } else {
    console.log('Run this SQL in Neon SQL Editor (Vercel → Storage → Neon → SQL Editor):\n');
    console.log(sql);
    console.log('\nOr set POSTGRES_URL and run this script to insert automatically.');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
