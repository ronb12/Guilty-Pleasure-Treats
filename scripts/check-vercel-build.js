#!/usr/bin/env node
/**
 * Check the build for empty API files and missing bakery/expected routes.
 * Uses Vercel CLI: runs `vercel build` then inspects output and api source.
 *
 * Usage:
 *   node scripts/check-vercel-build.js              # build + check api + check output
 *   node scripts/check-vercel-build.js --no-build    # check api/ and api-src/ only (no vercel build)
 *   node scripts/check-vercel-build.js --source      # check api-src/ only
 *
 * Empty files: any api/*.js (and nested) with 0 bytes.
 * Missing features: expected routes (from BAKERY_FEATURES_IMPLEMENTATION + core) not present or empty.
 */

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const apiDir = path.join(root, 'api');
const apiSrcDir = path.join(root, 'api-src');
const vercelOutput = path.join(root, '.vercel', 'output');
const functionsDir = path.join(vercelOutput, 'functions');

// Expected API routes (path without .js): core + bakery feature endpoints
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
  'orders/update-status',   // bakery
  'products/id',
  'stripe/create-checkout-session',
  'stripe/create-payment-intent',
  'stripe/refund',         // bakery
  'analytics/summary',
  'analytics/export',      // bakery
  'settings/business',
  'settings/custom-cake-options',
  'settings/business-hours', // bakery
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

function collectJsFiles(dir, prefix = '') {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    const rel = prefix ? `${prefix}/${name}` : name;
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      out.push(...collectJsFiles(full, rel));
    } else if (name.endsWith('.js')) {
      out.push({ path: full, rel: rel.replace(/\.js$/, ''), size: stat.size });
    }
  }
  return out;
}

function checkDir(dir, label) {
  const files = collectJsFiles(dir);
  const empty = files.filter((f) => f.size === 0);
  const byRoute = new Map(files.map((f) => [f.rel, f]));
  const missing = EXPECTED_ROUTES.filter((r) => !byRoute.has(r) || byRoute.get(r).size === 0);
  return { files, empty, missing, label };
}

function main() {
  const noBuild = process.argv.includes('--no-build');
  const sourceOnly = process.argv.includes('--source');

  console.log('--- Check API source for empty files and missing routes ---\n');

  const dirToCheck = sourceOnly ? apiSrcDir : apiDir;
  if (!fs.existsSync(dirToCheck)) {
    console.error('Directory not found:', dirToCheck);
    if (!sourceOnly && fs.existsSync(apiSrcDir)) {
      console.error('Tip: run sync first (e.g. ./scripts/sync-api-for-vercel.sh) or use --source to check api-src/');
    }
    process.exit(1);
  }

  const { empty, missing, label } = checkDir(dirToCheck, path.basename(dirToCheck));

  if (empty.length > 0) {
    console.log('Empty API files (0 bytes):');
    empty.forEach((f) => console.log('  ', f.rel + '.js'));
    console.log('');
  } else {
    console.log('No empty API files in', label, '\n');
  }

  if (missing.length > 0) {
    console.log('Missing or empty expected routes:');
    missing.forEach((r) => console.log('  ', r));
    console.log('');
  } else {
    console.log('All expected routes present and non-empty.\n');
  }

  if (!noBuild) {
    console.log('--- Running vercel build ---\n');
    const res = spawnSync('vercel', ['build', '--yes'], {
      cwd: root,
      stdio: 'inherit',
      shell: true,
    });
    if (res.status !== 0) {
      console.error('\nvercel build failed. Fix errors above, or run with --no-build to only check api/ source.');
      process.exit(res.status || 1);
    }
    console.log('\n--- Checking .vercel/output/functions ---\n');
    if (fs.existsSync(functionsDir)) {
      const funcs = fs.readdirSync(functionsDir, { withFileTypes: true });
      const small = [];
      function sizeOfFunc(dirPath) {
        let total = 0;
        try {
          for (const e of fs.readdirSync(dirPath, { withFileTypes: true })) {
            const p = path.join(dirPath, e.name);
            if (e.isDirectory()) total += sizeOfFunc(p);
            else total += fs.statSync(p).size;
          }
        } catch (_) {}
        return total;
      }
      for (const e of funcs) {
        if (!e.isDirectory()) continue;
        const p = path.join(functionsDir, e.name);
        const size = sizeOfFunc(p);
        if (size > 0 && size < 600) small.push({ name: e.name, size });
      }
      if (small.length > 0) {
        console.log('Very small function bundles (might be empty or stub):');
        small.forEach((f) => console.log('  ', f.name, f.size, 'bytes'));
      } else {
        console.log('No suspiciously small function bundles found.');
      }
    } else {
      console.log('No .vercel/output/functions directory (build may use different structure).');
    }
  }

  console.log('\n--- Summary ---');
  if (empty.length > 0 || missing.length > 0) {
    console.log('Issues found: empty files and/or missing routes. Sync api-src → api and redeploy if needed.');
    process.exit(1);
  }
  console.log('API source looks good. Use "vercel list" and "vercel inspect <url> --logs" to inspect deployed build logs.');
}

main();
