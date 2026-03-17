#!/usr/bin/env node
/**
 * Generate a bcrypt hash for a password. Use this to fix login when
 * password_hash in Neon was set to plain text by mistake.
 *
 * Usage: node scripts/hash-password.js "your password"
 * Then in Neon SQL Editor: UPDATE users SET password_hash = '<paste hash>' WHERE LOWER(TRIM(email)) = 'your@email.com';
 */
import bcrypt from 'bcryptjs';

const password = process.argv[2];
if (!password) {
  console.error('Usage: node scripts/hash-password.js "your password"');
  process.exit(1);
}

const hash = await bcrypt.hash(password, 10);
console.log('Copy this hash into Neon (users.password_hash):');
console.log(hash);
console.log('');
console.log('Then in Neon SQL Editor run (replace email):');
console.log("UPDATE users SET password_hash = '" + hash + "' WHERE LOWER(TRIM(email)) = 'your@email.com';");
