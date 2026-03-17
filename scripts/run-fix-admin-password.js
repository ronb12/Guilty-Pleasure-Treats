#!/usr/bin/env node
/**
 * Run fix-admin-password: set bcrypt hash for admin user so login works.
 * Usage: node --env-file=.env.neon scripts/run-fix-admin-password.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);
const HASH = '$2a$10$jcGh6c.LHDDyL7rzYjbJxOK1jA.1hw2cSCyJ0Ix0sbwfz0cEHt2bW';
const EMAIL = 'ronellbradley@hotmail.com';

async function main() {
  try {
    const updated = await sql`
      UPDATE users
      SET password_hash = ${HASH}
      WHERE LOWER(TRIM(email)) = ${EMAIL.toLowerCase()}
    `;
    console.log('Update applied for', EMAIL);

    const rows = await sql`
      SELECT email, display_name,
        CASE WHEN password_hash IS NOT NULL AND password_hash LIKE '$2%' THEN 'yes' ELSE 'no' END AS has_password
      FROM users
      WHERE LOWER(TRIM(email)) = ${EMAIL.toLowerCase()}
    `;
    if (rows.length) {
      console.log('Verified:', rows[0]);
      console.log('Sign in with email:', EMAIL, 'password: password1234');
    } else {
      console.log('No user found with that email. Run the SQL in Neon with your admin email.');
    }
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
