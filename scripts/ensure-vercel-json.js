#!/usr/bin/env node
/**
 * Ensure vercel.json exists with buildCommand so Git deploys run api sync.
 * Retries; if project dir times out, writes to /tmp and prints copy command.
 * Run: node scripts/ensure-vercel-json.js
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

const root = path.resolve(__dirname, '..');
const vercelJson = path.join(root, 'vercel.json');
const buildConfig = { buildCommand: 'node scripts/sync-api-for-vercel.js' };

const MAX_RETRIES = 5;
const RETRY_DELAY_MS = 300;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function isTimeout(e) {
  return e.code === 'ETIMEDOUT' || (e.message && String(e.message).includes('timed out'));
}

async function main() {
  let existing = {};
  try {
    if (fs.existsSync(vercelJson)) {
      existing = JSON.parse(fs.readFileSync(vercelJson, 'utf8'));
    }
  } catch (e) {
    if (!isTimeout(e)) throw e;
  }
  const merged = { ...existing, ...buildConfig };
  const content = JSON.stringify(merged, null, 2) + '\n';

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const tmpPath = vercelJson + '.tmp.' + process.pid;
      fs.writeFileSync(tmpPath, content, 'utf8');
      fs.renameSync(tmpPath, vercelJson);
      console.log('vercel.json updated with buildCommand:', buildConfig.buildCommand);
      process.exit(0);
    } catch (e) {
      if (!isTimeout(e)) {
        console.error(e.message);
        process.exit(1);
      }
      if (attempt < MAX_RETRIES) await sleep(RETRY_DELAY_MS * attempt);
    }
  }

  const fallback = path.join(os.tmpdir(), 'vercel.json.guilty-pleasure-treats');
  try {
    fs.writeFileSync(fallback, content, 'utf8');
    console.log('Wrote to', fallback, '(project dir timed out). Copy into project root:');
    console.log('  cp', fallback, root + '/vercel.json');
    process.exit(0);
  } catch (e2) {
    console.error('Fallback write failed:', e2.message);
    process.exit(1);
  }
}

main();
