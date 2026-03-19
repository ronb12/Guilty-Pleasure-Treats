#!/usr/bin/env node
/**
 * List recent Vercel deployments with creation time (for finding "8 AM this morning" etc.).
 * Requires: VERCEL_TOKEN (vercel.com → Account → Settings → Tokens).
 *
 * Usage:
 *   VERCEL_TOKEN=xxx node scripts/list-vercel-deployments.js
 *   VERCEL_TOKEN=xxx node scripts/list-vercel-deployments.js --limit 30
 */

const https = require('https');
const path = require('path');

const token = process.env.VERCEL_TOKEN;
const argv = process.argv.slice(2);
const limitIdx = argv.indexOf('--limit');
const limit = limitIdx >= 0 && argv[limitIdx + 1] ? parseInt(argv[limitIdx + 1], 10) : 20;

if (!token) {
  console.error('Set VERCEL_TOKEN (vercel.com → Account → Settings → Tokens).');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
let projectId = process.env.VERCEL_PROJECT_ID;
if (!projectId) {
  try {
    const j = JSON.parse(require('fs').readFileSync(path.join(root, '.vercel', 'project.json'), 'utf8'));
    projectId = j.projectId;
  } catch (_) {}
}
if (!projectId) {
  console.error('Could not find project. Link with: vercel link');
  process.exit(1);
}

function request(method, pathname, qs = {}) {
  const q = new URLSearchParams({ ...qs, projectId }).toString();
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'api.vercel.com',
        path: pathname + (q ? '?' + q : ''),
        method,
        headers: { Authorization: 'Bearer ' + token },
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch {
            reject(new Error(body || res.statusCode));
          }
        });
      }
    );
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  const list = await request('GET', '/v6/deployments', { limit: Math.min(limit, 100) });
  const deployments = list.deployments || [];
  console.log('Recent deployments (newest first):\n');
  console.log('Created (UTC)              | State      | Production | URL / ID');
  console.log('-'.repeat(90));
  for (const d of deployments) {
    const created = d.created ? new Date(d.created).toISOString().replace('T', ' ').slice(0, 19) : '-';
    const state = (d.state || '-').padEnd(10);
    const prod = d.target === 'production' ? 'yes' : '';
    const url = d.url || d.uid || '-';
    console.log(`${created} | ${state} | ${prod.padEnd(10)} | ${url}`);
  }
  console.log('\nTo use the app from 8:00 AM this morning:');
  console.log('  1. Find the deployment row that was created around 8 AM your time.');
  console.log('  2. Run: vercel rollback <deployment-url-or-uid>');
  console.log('     Example: vercel rollback guilty-pleasure-treats-xxxxx.vercel.app');
  console.log('  Or in Vercel Dashboard: Deployments → ⋮ next to that deployment → "Instant Rollback".');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
