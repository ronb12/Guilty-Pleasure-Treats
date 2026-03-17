#!/usr/bin/env node
/**
 * Add or update admin user in Neon. Requires POSTGRES_URL.
 * Usage: node --env-file=.env.neon scripts/add-admin-user.js
 */
import { neon } from '@neondatabase/serverless';
import bcrypt from 'bcryptjs';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL (or DATABASE_URL). Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

const ADMINS = [
  { email: 'ronellbradley@hotmail.com', password: 'password1234' },
  { email: 'abradley1@gmail.com', password: 'admin1234' },
];

async function main() {
  try {
    for (const { email, password } of ADMINS) {
      const passwordHash = await bcrypt.hash(password, 10);
      const normalizedEmail = email.trim().toLowerCase();

      await sql`
        INSERT INTO users (email, display_name, password_hash, is_admin, points)
        VALUES (${normalizedEmail}, ${'Admin'}, ${passwordHash}, true, 0)
        ON CONFLICT (email) DO UPDATE SET
          password_hash = EXCLUDED.password_hash,
          is_admin = true,
          updated_at = NOW()
      `;
      console.log('Admin user added/updated:', normalizedEmail);
    }
    console.log('You can sign in in the app with any of these emails and passwords.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
