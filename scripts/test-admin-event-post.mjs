#!/usr/bin/env node
/**
 * Integration test: POST /api/auth/login then POST /api/events (admin).
 * Requires env: TEST_ADMIN_EMAIL, TEST_ADMIN_PASSWORD
 * Optional: TEST_BASE_URL (default https://guilty-pleasure-treats.vercel.app)
 *
 * Usage:
 *   TEST_ADMIN_EMAIL=you@example.com TEST_ADMIN_PASSWORD='secret' node scripts/test-admin-event-post.mjs
 */
const base = (process.env.TEST_BASE_URL || 'https://guilty-pleasure-treats.vercel.app').replace(/\/$/, '');
const email = process.env.TEST_ADMIN_EMAIL || '';
const password = process.env.TEST_ADMIN_PASSWORD || '';

async function main() {
  if (!email || !password) {
    console.error('Set TEST_ADMIN_EMAIL and TEST_ADMIN_PASSWORD to run the live test.');
    process.exit(2);
  }

  const loginRes = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const loginText = await loginRes.text();
  if (!loginRes.ok) {
    console.error(`Login failed HTTP ${loginRes.status}: ${loginText.slice(0, 500)}`);
    process.exit(1);
  }
  let loginJson;
  try {
    loginJson = JSON.parse(loginText);
  } catch {
    console.error('Login: invalid JSON');
    process.exit(1);
  }
  const token = loginJson.token;
  const isAdmin = loginJson.user?.isAdmin === true;
  if (!token) {
    console.error('Login: no token in response');
    process.exit(1);
  }
  console.log(`Login OK. isAdmin=${isAdmin} tokenKind=${token.split('.').length === 3 ? 'jwt' : 'session'}`);

  if (!isAdmin) {
    console.error('User is not admin in login response — set is_admin=true in Neon for this user, then retry.');
    process.exit(1);
  }

  const title = `Automated test ${new Date().toISOString()}`;
  const eventRes = await fetch(`${base}/api/events`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ title, description: 'scripts/test-admin-event-post.mjs' }),
  });
  const eventText = await eventRes.text();
  if (eventRes.status === 201) {
    console.log('POST /api/events OK (201)');
    console.log(eventText.slice(0, 400));
    process.exit(0);
  }
  console.error(`POST /api/events failed HTTP ${eventRes.status}: ${eventText.slice(0, 800)}`);
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
