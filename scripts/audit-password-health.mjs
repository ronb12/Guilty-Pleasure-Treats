#!/usr/bin/env node
/**
 * Read-only Neon audit: public.users password_hash vs neon_auth.account (credential).
 *
 *   node --env-file=.env.neon scripts/audit-password-health.mjs
 *
 * Does not print password hashes or full connection strings.
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL or DATABASE_URL (e.g. node --env-file=.env.neon scripts/audit-password-health.mjs)');
  process.exit(1);
}

const sql = neon(connectionString);

function maskEmail(e) {
  if (!e || typeof e !== 'string') return '(none)';
  const s = e.trim();
  const at = s.indexOf('@');
  if (at <= 1) return s[0] + '***';
  return s[0] + '***' + s.slice(at);
}

async function main() {
  console.log('Neon password / auth health (read-only)\n');

  const [userTotal] = await sql`SELECT COUNT(*)::int AS n FROM users`;
  console.log('public.users rows:', userTotal?.n ?? '?');

  const [noHash] = await sql`
    SELECT COUNT(*)::int AS n
    FROM users
    WHERE password_hash IS NULL OR LENGTH(TRIM(COALESCE(password_hash, ''))) < 10
  `;
  console.log('users with NULL or short password_hash (<10 chars):', noHash?.n ?? '?');

  const [adminNoHash] = await sql`
    SELECT COUNT(*)::int AS n
    FROM users
    WHERE (is_admin = true OR is_admin::text IN ('1', 't', 'true'))
      AND (password_hash IS NULL OR LENGTH(TRIM(COALESCE(password_hash, ''))) < 10)
  `;
  console.log('admin users with NULL or short password_hash:', adminNoHash?.n ?? '?');

  const adminsNeedingHash = await sql`
    SELECT id, email, neon_auth_id,
           LENGTH(TRIM(COALESCE(password_hash, ''))) AS hash_len
    FROM users
    WHERE (is_admin = true OR is_admin::text IN ('1', 't', 'true'))
      AND (password_hash IS NULL OR LENGTH(TRIM(COALESCE(password_hash, ''))) < 10)
    ORDER BY email NULLS LAST
    LIMIT 20
  `;
  if (adminsNeedingHash.length > 0) {
    console.log('\nSample admin rows without usable password_hash (max 20, masked email):');
    for (const r of adminsNeedingHash) {
      console.log(
        `  id=${r.id} email=${maskEmail(r.email)} neon_auth_id=${r.neon_auth_id ? 'set' : 'null'} hash_len=${r.hash_len}`
      );
    }
  }

  let credCount = null;
  let neonUserCount = null;
  try {
    const [c] = await sql`
      SELECT COUNT(*)::int AS n FROM neon_auth.account WHERE "providerId" = 'credential'
    `;
    credCount = c?.n;
    const [u] = await sql`SELECT COUNT(*)::int AS n FROM neon_auth."user"`;
    neonUserCount = u?.n;
    console.log('\nneon_auth.user rows:', neonUserCount ?? '?');
    console.log('neon_auth.account credential rows:', credCount ?? '?');
  } catch (e) {
    console.log('\nneon_auth schema:', e?.code || e?.message || e);
  }

  if (credCount != null) {
    const orphanCred = await sql`
      SELECT COUNT(*)::int AS n
      FROM neon_auth.account a
      WHERE a."providerId" = 'credential'
        AND NOT EXISTS (
          SELECT 1 FROM users u
          WHERE TRIM(COALESCE(u.neon_auth_id::text, '')) = TRIM(a."userId"::text)
             OR TRIM(u.id::text) = TRIM(a."userId"::text)
        )
    `;
    console.log('credential accounts with no matching users.neon_auth_id or users.id:', orphanCred[0]?.n ?? '?');

    const usersMissingCred = await sql`
      SELECT u.id, u.email, u.neon_auth_id
      FROM users u
      WHERE u.email IS NOT NULL AND TRIM(u.email) <> ''
        AND NOT EXISTS (
          SELECT 1 FROM neon_auth.account a
          WHERE a."providerId" = 'credential'
            AND TRIM(a."userId"::text) = TRIM(COALESCE(NULLIF(u.neon_auth_id::text, ''), u.id::text))
        )
      ORDER BY u.email
      LIMIT 15
    `;
    console.log('\nUsers with email but no neon_auth credential row (first 15, masked):');
    if (usersMissingCred.length === 0) {
      console.log('  (none in sample limit — or all have credential)');
    } else {
      for (const r of usersMissingCred) {
        console.log(`  id=${r.id} ${maskEmail(r.email)} neon_auth_id=${r.neon_auth_id ? 'set' : 'null'}`);
      }
    }
  }

  console.log('\nNotes:');
  console.log('- Login tries Neon Auth first, then users.password_hash (bcrypt).');
  console.log('- If Neon sign-in fails and password_hash is empty/short, email/password login will fail.');
  console.log('- Fix: node --env-file=.env.neon scripts/set-user-password.mjs <email> <password>');
  console.log('- Sync Neon credential from bcrypt: node --env-file=.env.neon scripts/sync-users-to-neon-auth.js');
}

main().catch((e) => {
  console.error(e?.message ?? e);
  process.exit(1);
});
