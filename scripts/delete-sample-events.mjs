#!/usr/bin/env node
/**
 * Remove integration-test / placeholder rows from `events`.
 *
 * Matches:
 *   - Admin seed: description mentions "Seeded to verify the Events list" / title "Sample: Weekend tasting…"
 *   - Integration test: scripts/test-admin-event-post.mjs (description + "Automated test" titles)
 *
 * Usage:
 *   node --env-file=.env.neon scripts/delete-sample-events.mjs
 *   POSTGRES_URL='postgresql://...' node scripts/delete-sample-events.mjs
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL or DATABASE_URL (e.g. node --env-file=.env.neon scripts/delete-sample-events.mjs)');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  const deleted = await sql`
    DELETE FROM events
    WHERE description ILIKE '%Seeded to verify the Events list and Save in admin%'
       OR title ILIKE 'Sample: Weekend tasting%'
       OR description = 'scripts/test-admin-event-post.mjs'
       OR title ILIKE 'Automated test%'
    RETURNING id, title
  `;
  const rows = Array.isArray(deleted) ? deleted : [];
  if (rows.length === 0) {
    console.log('No matching sample/test events found (nothing deleted).');
    return;
  }
  console.log(`Deleted ${rows.length} event(s):`);
  for (const r of rows) {
    console.log(`  - ${r.title} (${r.id})`);
  }
}

main().catch((e) => {
  console.error(e?.message ?? e);
  process.exit(1);
});
