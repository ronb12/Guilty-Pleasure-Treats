#!/usr/bin/env node
/**
 * Compare Vercel deployed builds to the app's expected API (core + bakery features).
 * By default scans ALL recent builds (production + preview); reports each and a summary.
 *
 * Requires: VERCEL_TOKEN (vercel.com → Account → Settings → Tokens).
 * Optional: VERCEL_DEPLOYMENT_ID, VERCEL_PROJECT_ID, VERCEL_TEAM_ID.
 *
 * Usage:
 *   VERCEL_TOKEN=xxx node scripts/check-vercel-deployment-vs-app.js
 *     # Scan all recent deployments (default limit 20)
 *   VERCEL_TOKEN=xxx node scripts/check-vercel-deployment-vs-app.js --limit 50
 *     # Scan up to 50 recent builds
 *   VERCEL_TOKEN=xxx node scripts/check-vercel-deployment-vs-app.js --latest
 *     # Only check the single latest production deployment (legacy behavior)
 *   VERCEL_TOKEN=xxx node scripts/check-vercel-deployment-vs-app.js --preview
 *     # With --latest: only latest preview instead of production
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const token = process.env.VERCEL_TOKEN;
const deploymentId = process.env.VERCEL_DEPLOYMENT_ID;
const teamId = process.env.VERCEL_TEAM_ID;
const argv = process.argv.slice(2);
const usePreview = argv.includes('--preview');
const latestOnly = argv.includes('--latest') || deploymentId;
const limitIdx = argv.indexOf('--limit');
const scanLimit = limitIdx >= 0 && argv[limitIdx + 1] ? parseInt(argv[limitIdx + 1], 10) : 20;

if (!token) {
  console.error('Set VERCEL_TOKEN (vercel.com → Account → Settings → Tokens).');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');

// Same as check-vercel-build.js: core + bakery
const EXPECTED_ROUTES = [
  'health',
  'index',
  'orders',
  'products',
  'admin-messages',
  'upload',
  'auth/login',
  'auth/signup',
  'auth/apple',
  'auth/me',
  'auth/logout',
  'auth/forgot-password',
  'auth/reset-password',
  'auth/set-password',
  'auth/delete-account',
  'orders/id',
  'orders/update-status',
  'products/id',
  'stripe/create-checkout-session',
  'stripe/create-payment-intent',
  'stripe/refund',
  'analytics/summary',
  'analytics/export',
  'settings/business',
  'settings/custom-cake-options',
  'settings/business-hours',
  'contact/index',
  'contact/id',
  'contact/reply',
  'contact/replies',
  'contact/replies-id',
  'custom-cake-orders/index',
  'custom-cake-orders/id',
  'custom-cake-options/index',
  'ai-cake-designs/index',
  'ai-cake-designs/id',
  'ai/generate-image',
  'cake-gallery/index',
  'cake-gallery/id',
  'events/index',
  'events/id',
  'promotions/index',
  'promotions/id',
  'promotions/code/code',
  'product-categories/index',
  'product-categories/id',
  'customers/index',
  'customers/id',
  'reviews/index',
  'reviews/id',
  'messages/index',
  'users/me',
  'push/register',
];

const BAKERY_FEATURE_ROUTES = [
  'orders/update-status',
  'stripe/refund',
  'analytics/export',
  'settings/business-hours',
];

function request(method, pathname, query = {}) {
  const q = { ...query };
  if (teamId) q.teamId = teamId;
  const qs = new URLSearchParams(q).toString();
  const url = `https://api.vercel.com${pathname}${qs ? '?' + qs : ''}`;
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      { method, headers: { Authorization: `Bearer ${token}` } },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          try {
            const data = body ? JSON.parse(body) : {};
            if (res.statusCode >= 400) reject(new Error(data.error?.message || body || res.statusCode));
            else resolve(data);
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.end();
  });
}

function collectFiles(tree, prefix = '') {
  const out = [];
  for (const entry of tree || []) {
    const name = entry.name;
    const full = prefix ? `${prefix}/${name}` : name;
    if (entry.type === 'file' && name.endsWith('.js')) out.push({ ...entry, path: full });
    if (entry.type === 'directory' && entry.children) out.push(...collectFiles(entry.children, full));
  }
  return out;
}

function getProjectId() {
  const p = process.env.VERCEL_PROJECT_ID;
  if (p) return p;
  try {
    const j = JSON.parse(fs.readFileSync(path.join(root, '.vercel', 'project.json'), 'utf8'));
    return j.projectId;
  } catch (_) {
    return undefined;
  }
}

async function getLatestDeployment() {
  if (deploymentId) {
    const dep = await request('GET', `/v13/deployments/${deploymentId}`);
    return [{ uid: dep.id || dep.uid, url: dep.url, state: dep.readyState, target: dep.target || 'production' }];
  }
  const projectId = getProjectId();
  const q = { limit: '1' };
  if (projectId) q.projectId = projectId;
  q.target = usePreview ? 'preview' : 'production';
  const list = await request('GET', '/v6/deployments', q);
  const dep = list.deployments?.[0];
  if (!dep?.uid) throw new Error('No deployment found. Set VERCEL_DEPLOYMENT_ID or ensure project has deployments.');
  return [{ uid: dep.uid, url: dep.url, state: dep.state, target: dep.target || (usePreview ? 'preview' : 'production') }];
}

async function listDeployments(limit) {
  const projectId = getProjectId();
  const q = { limit: String(limit) };
  if (projectId) q.projectId = projectId;
  const list = await request('GET', '/v6/deployments', q);
  const deployments = list.deployments || [];
  return deployments.map((d) => ({
    uid: d.uid,
    url: d.url,
    state: d.state,
    target: d.target || 'preview',
    created: d.created,
  }));
}

function analyzeDeployment(deployedRoutes) {
  const missing = EXPECTED_ROUTES.filter((r) => !deployedRoutes.has(r));
  const missingBakery = BAKERY_FEATURE_ROUTES.filter((r) => !deployedRoutes.has(r));
  return { missing, missingBakery };
}

async function getDeployedRoutesForDeployment(depId) {
  const tree = await request('GET', `/v6/deployments/${depId}/files`);
  const files = collectFiles(tree);
  const apiFiles = files.filter((f) => f.path.startsWith('api/') && !f.path.startsWith('api/lib/'));
  const deployedRoutes = new Set(
    apiFiles.map((f) => f.path.replace(/^api\//, '').replace(/\.js$/, ''))
  );
  return { apiCount: apiFiles.length, deployedRoutes };
}

async function main() {
  if (latestOnly) {
    console.log('Fetching latest', usePreview ? 'preview' : 'production', 'deployment...\n');
    const deployments = await getLatestDeployment();
    const deployment = deployments[0];
    const depId = deployment.uid;
    const depUrl = deployment.url || depId;
    const state = deployment.state;

    console.log('Deployment:', depUrl);
    console.log('State:', state);
    console.log('');

    const { apiCount, deployedRoutes } = await getDeployedRoutesForDeployment(depId);
    const { missing, missingBakery } = analyzeDeployment(deployedRoutes);

    console.log('--- Deployed API routes ---');
    console.log('Total api/*.js in deployment:', apiCount);
    if (deployedRoutes.size <= 30) {
      [...deployedRoutes].sort().forEach((r) => console.log('  ', r));
    } else {
      [...deployedRoutes].sort().slice(0, 20).forEach((r) => console.log('  ', r));
      console.log('  ... and', deployedRoutes.size - 20, 'more');
    }
    console.log('');

    console.log('--- Missing vs app expectations ---');
    if (missing.length === 0) {
      console.log('None. All expected routes are present in this deployment.\n');
    } else {
      console.log('Missing routes (' + missing.length + '):');
      missing.forEach((r) => {
        const isBakery = BAKERY_FEATURE_ROUTES.includes(r);
        console.log('  ', r, isBakery ? '[bakery feature]' : '');
      });
      console.log('');
    }

    console.log('--- Bakery features (from BAKERY_FEATURES_IMPLEMENTATION) ---');
    for (const r of BAKERY_FEATURE_ROUTES) {
      const present = deployedRoutes.has(r);
      console.log('  ', present ? '✓' : '✗', r);
    }
    if (missingBakery.length > 0) {
      console.log('\nMissing bakery endpoints:', missingBakery.join(', '));
      console.log('Add and deploy: api-src/' + missingBakery.map((r) => r + '.js').join(', api-src/') + ', then sync and redeploy.');
    }
    console.log('');

    console.log('--- Summary ---');
    if (missing.length === 0) {
      console.log('Deployment matches app expectations. No missing features.');
    } else {
      console.log('Missing in deployment:', missing.length, 'routes');
      if (missingBakery.length > 0) console.log('Missing bakery features:', missingBakery.length);
      process.exit(1);
    }
    return;
  }

  console.log('Scanning up to', scanLimit, 'recent Vercel builds...\n');

  const deployments = await listDeployments(scanLimit);
  if (deployments.length === 0) {
    console.log('No deployments found.');
    process.exit(1);
  }

  const results = [];
  for (let i = 0; i < deployments.length; i++) {
    const d = deployments[i];
    process.stderr.write('  Checking ' + (i + 1) + '/' + deployments.length + ' ' + (d.url || d.uid) + '...');
    try {
      const { apiCount, deployedRoutes } = await getDeployedRoutesForDeployment(d.uid);
      const { missing, missingBakery } = analyzeDeployment(deployedRoutes);
      results.push({
        uid: d.uid,
        url: d.url || d.uid,
        state: d.state,
        target: d.target,
        created: d.created,
        apiCount,
        missingCount: missing.length,
        missingBakeryCount: missingBakery.length,
        missing,
        missingBakery,
        deployedRoutes,
      });
      process.stderr.write(' ' + apiCount + ' api routes, ' + missing.length + ' missing\n');
    } catch (e) {
      process.stderr.write(' error: ' + (e.message || e) + '\n');
      results.push({
        uid: d.uid,
        url: d.url || d.uid,
        state: d.state,
        target: d.target,
        created: d.created,
        error: e.message || String(e),
      });
    }
  }

  console.log('\n--- All builds ---\n');
  const col = (s, w) => String(s).slice(0, w).padEnd(w);
  console.log(col('URL', 52) + col('Target', 12) + col('State', 12) + 'API#   Missing  Bakery');
  console.log('-'.repeat(52 + 12 + 12 + 8 + 8 + 8));
  let anyOk = false;
  let anyFail = false;
  for (const r of results) {
    if (r.error) {
      console.log(col(r.url, 52) + col(r.target || '-', 12) + col(r.state || '-', 12) + '  -       (error)');
      continue;
    }
    if (r.missingCount === 0) anyOk = true;
    else anyFail = true;
    console.log(
      col(r.url, 52) + col(r.target || '-', 12) + col(r.state || '-', 12) +
      String(r.apiCount).padStart(5) + '  ' + String(r.missingCount).padStart(6) + '  ' + String(r.missingBakeryCount).padStart(6)
    );
  }

  console.log('\n--- Builds missing routes (detail) ---\n');
  const withMissing = results.filter((r) => !r.error && r.missingCount > 0);
  if (withMissing.length === 0 && results.some((r) => !r.error)) {
    console.log('None. All scanned builds have the expected API routes.\n');
  } else {
    for (const r of withMissing) {
      console.log(r.url + ' [' + r.target + '] – missing ' + r.missingCount + ' routes (' + r.missingBakeryCount + ' bakery)');
      if (r.missingBakery.length > 0) {
        console.log('  Bakery:', r.missingBakery.join(', '));
      }
      if (r.missingCount <= 15) {
        r.missing.forEach((m) => console.log('  -', m));
      } else {
        r.missing.slice(0, 10).forEach((m) => console.log('  -', m));
        console.log('  ... and', r.missingCount - 10, 'more');
      }
      console.log('');
    }
  }

  console.log('--- Summary ---');
  const ok = results.filter((r) => !r.error && r.missingCount === 0).length;
  const err = results.filter((r) => r.error).length;
  console.log('Scanned', results.length, 'builds:', ok, 'complete (all routes),', withMissing.length, 'missing routes,', err, 'errors.');
  if (anyFail && !anyOk) {
    console.log('All builds are missing API routes. Sync api-src → api and redeploy.');
    process.exit(1);
  }
  if (anyFail) {
    console.log('Some builds are incomplete. Ensure every deploy runs sync (e.g. buildCommand in vercel.json).');
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
