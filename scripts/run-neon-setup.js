#!/usr/bin/env node
/**
 * Run api/neon-setup.sql (schema + admin user) against Neon.
 * Use with Neon CLI: npx neonctl set-context --project-id <id> && POSTGRES_URL="$(npx neonctl connection-string)" node scripts/run-neon-setup.js
 * Or: POSTGRES_URL='postgresql://...' node scripts/run-neon-setup.js
 */
import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const setupPath = join(__dirname, '..', 'api', 'neon-setup.sql');

const connectionString = process.env.POSTGRES_URL || process.argv[2];
if (!connectionString) {
  console.error('Set POSTGRES_URL or pass connection string as first argument.');
  console.error('With Neon CLI: POSTGRES_URL="$(npx neonctl connection-string)" node scripts/run-neon-setup.js');
  process.exit(1);
}

const raw = readFileSync(setupPath, 'utf8');
// Same approach as run-schema: strip comment lines, then split by ;
const statements = raw
  .split('\n')
  .filter((line) => !line.trim().startsWith('--'))
  .join('\n')
  .split(';')
  .map((s) => s.trim())
  .filter(Boolean);

async function main() {
  const client = new pg.Client({ connectionString });
  await client.connect();
  try {
    for (const statement of statements) {
      const full = statement.endsWith(';') ? statement : statement + ';';
      await client.query(full);
      const preview = full.slice(0, 60).replace(/\s+/g, ' ');
      console.log('OK:', preview + (full.length > 60 ? '...' : ''));
    }
    console.log('\nNeon setup complete: tables + admin user (ronellbradley@hotmail.com / password1234).');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
