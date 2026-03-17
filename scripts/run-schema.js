#!/usr/bin/env node
/**
 * Run api/schema.sql against Neon. Requires POSTGRES_URL or connection string as first arg.
 * Usage: POSTGRES_URL='...' node scripts/run-schema.js
 *    or: node scripts/run-schema.js 'postgresql://...'
 */
import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const schemaPath = join(__dirname, '..', 'api', 'schema.sql');

const connectionString = process.env.POSTGRES_URL || process.argv[2];
if (!connectionString) {
  console.error('Set POSTGRES_URL or pass connection string as first argument.');
  process.exit(1);
}

// Strip comments and split into statements
const raw = readFileSync(schemaPath, 'utf8');
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
      if (!statement) continue;
      const full = statement.endsWith(';') ? statement : statement + ';';
      await client.query(full);
      console.log('OK:', full.slice(0, 55).replace(/\s+/g, ' ') + '...');
    }
    console.log('Schema applied successfully.');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
