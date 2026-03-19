#!/usr/bin/env node
/**
 * Sync public.users → neon_auth.user and neon_auth.account (credential)
 * so that Neon Auth sign-in works for every user in public.users.
 * - Ensures each public.users row has a neon_auth.user (same id, or link via neon_auth_id)
 * - Ensures credential account exists with password = public.users.password_hash
 *
 * Usage: POSTGRES_URL=<connection_string> node scripts/sync-users-to-neon-auth.js
 *    or: node --env-file=.env.neon scripts/sync-users-to-neon-auth.js
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL or DATABASE_URL');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  console.log('Syncing public.users → neon_auth.user + neon_auth.account (credential)\n');

  const users = await sql`
    SELECT id, email, display_name, password_hash, neon_auth_id
    FROM public.users
    ORDER BY email
  `;
  if (!users.length) {
    console.log('No users in public.users.');
    return;
  }

  for (const u of users) {
    const neonUserId = u.neon_auth_id || u.id;
    const name = u.display_name || u.email || 'User';
    const email = (u.email || '').trim().toLowerCase();
    if (!email) {
      console.log('Skip', u.id, '(no email)');
      continue;
    }

    // 1. Ensure neon_auth.user exists (use neon_auth_id or public.users.id as id)
    const existingNeonUser = await sql`
      SELECT id FROM neon_auth."user" WHERE id = ${neonUserId} LIMIT 1
    `;
    if (existingNeonUser.length === 0) {
      const byEmail = await sql`
        SELECT id FROM neon_auth."user" WHERE LOWER(email) = ${email} LIMIT 1
      `;
      if (byEmail.length > 0) {
        const linkedId = byEmail[0].id;
        await sql`UPDATE public.users SET neon_auth_id = ${linkedId}, updated_at = NOW() WHERE id = ${u.id}`;
        console.log('Linked', email, 'to existing neon_auth.user', linkedId);
        if (u.password_hash) {
          await ensureCredentialAccount(linkedId, u.password_hash);
        }
        continue;
      }
      await sql`
        INSERT INTO neon_auth."user" (id, name, email, "emailVerified", "createdAt", "updatedAt")
        VALUES (${neonUserId}, ${name}, ${email}, false, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET name = ${name}, email = ${email}, "updatedAt" = NOW()
      `;
      if (!u.neon_auth_id) {
        await sql`UPDATE public.users SET neon_auth_id = ${neonUserId}, updated_at = NOW() WHERE id = ${u.id}`;
      }
      console.log('Created/updated neon_auth.user', email, '(id:', neonUserId, ')');
    }

    // 2. Ensure credential account exists with password from public.users
    if (u.password_hash) {
      await ensureCredentialAccount(neonUserId, u.password_hash);
    }
  }

  console.log('\nDone. Neon Auth and public.users are in sync.');
}

async function ensureCredentialAccount(userId, passwordHash) {
  const existing = await sql`
    SELECT id, password FROM neon_auth.account
    WHERE "userId" = ${userId} AND "providerId" = 'credential'
    LIMIT 1
  `;
  if (existing.length > 0) {
    if (existing[0].password !== passwordHash) {
      await sql`
        UPDATE neon_auth.account
        SET password = ${passwordHash}, "updatedAt" = NOW()
        WHERE "userId" = ${userId} AND "providerId" = 'credential'
      `;
      console.log('  Updated credential password for user', userId);
    }
    return;
  }
  const { randomUUID } = await import('crypto');
  await sql`
    INSERT INTO neon_auth.account (id, "accountId", "providerId", "userId", password, "createdAt", "updatedAt")
    VALUES (${randomUUID()}, ${userId}, 'credential', ${userId}, ${passwordHash}, NOW(), NOW())
  `;
  console.log('  Created credential account for user', userId);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
