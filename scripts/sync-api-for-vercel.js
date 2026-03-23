#!/usr/bin/env node
/**
 * Syncs api-src into api for Vercel deploy. Keeps api/lib intact.
 * Run before deploy: node scripts/sync-api-for-vercel.js
 *
 * Uses (in order):
 * 1. Stream copy (readStream.pipe(writeStream)) with retries
 * 2. Chunked read/write fallback (no copyfile, no mmap) if stream times out
 * Retries each file up to 3 times to avoid transient timeouts.
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const apiSrc = path.join(root, 'api-src');
const apiDir = path.join(root, 'api');

const RETRIES = 3;
const RETRY_DELAY_MS = 400;
const CHUNK_SIZE = 64 * 1024; // 64kb for chunked fallback

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

/** Copy via streams (no copyfile syscall). */
function copyFileStream(src, dest) {
  return new Promise((resolve, reject) => {
    const read = fs.createReadStream(src);
    const write = fs.createWriteStream(dest);
    read.on('error', reject);
    write.on('error', reject);
    write.on('finish', resolve);
    read.pipe(write);
  });
}

/** Copy via chunked readSync/writeSync (avoids copyfile and mmap). */
function copyFileChunked(src, dest) {
  const fdRead = fs.openSync(src, 'r');
  const fdWrite = fs.openSync(dest, 'w');
  try {
    const stat = fs.fstatSync(fdRead);
    const size = stat.size || 0;
    if (size === 0) return;
    const buf = Buffer.allocUnsafe(Math.min(CHUNK_SIZE, size));
    let offset = 0;
    while (offset < size) {
      const n = fs.readSync(fdRead, buf, 0, Math.min(buf.length, size - offset), offset);
      if (n <= 0) break;
      fs.writeSync(fdWrite, buf, 0, n);
      offset += n;
    }
  } finally {
    try { fs.closeSync(fdRead); } catch (_) {}
    try { fs.closeSync(fdWrite); } catch (_) {}
  }
}

async function copyOneFile(src, dest) {
  const dir = path.dirname(dest);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  let lastErr;
  for (let attempt = 0; attempt < RETRIES; attempt++) {
    try {
      await copyFileStream(src, dest);
      return;
    } catch (err) {
      lastErr = err;
      if (attempt < RETRIES - 1) await delay(RETRY_DELAY_MS);
    }
  }
  try {
    copyFileChunked(src, dest);
  } catch (e) {
    throw lastErr || e;
  }
}

async function copyRecursive(src, dest, excludeDir) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    if (path.basename(src) === excludeDir) return;
    if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
    for (const name of fs.readdirSync(src)) {
      await copyRecursive(path.join(src, name), path.join(dest, name), excludeDir);
    }
  } else {
    await copyOneFile(src, dest);
  }
}

async function main() {
  if (!fs.existsSync(apiSrc)) {
    console.error('api-src folder not found.');
    process.exit(1);
  }

  if (!fs.existsSync(apiDir)) {
    fs.mkdirSync(apiDir, { recursive: true });
  }

  for (const name of fs.readdirSync(apiSrc)) {
    if (name === 'lib') continue;
    const srcPath = path.join(apiSrc, name);
    const destPath = path.join(apiDir, name);
    if (fs.existsSync(destPath)) {
      const destStat = fs.statSync(destPath);
      if (destStat.isDirectory()) {
        try { fs.rmSync(destPath, { recursive: true }); } catch (_) {}
      } else {
        try { fs.unlinkSync(destPath); } catch (_) {}
      }
    }
    await copyRecursive(srcPath, destPath, null);
  }

  // Keep api/stripe/create-payment-intent.js and create-checkout-session.js so Vercel
  // deploys real serverless routes at those URLs (iOS POST /api/stripe/create-payment-intent).

  console.log('Synced api-src -> api for Vercel (api/lib unchanged).');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
