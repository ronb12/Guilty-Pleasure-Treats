#!/usr/bin/env node
/**
 * Restore api/*.js content from a Vercel deployment (build source).
 * Requires: VERCEL_TOKEN env var (create at vercel.com → Account → Settings → Tokens).
 * Optional: VERCEL_DEPLOYMENT_ID (default: fetch latest production).
 * Optional: VERCEL_TEAM_ID or VERCEL_ORG_ID for teams.
 *
 * Usage:
 *   VERCEL_TOKEN=xxx node scripts/restore-api-from-vercel-deployment.js
 *   VERCEL_TOKEN=xxx VERCEL_DEPLOYMENT_ID=dpl_xxx node scripts/restore-api-from-vercel-deployment.js
 *
 * Uses Vercel REST API:
 *   GET /v5/deployments (list) or /v13/deployments/{id}
 *   GET /v6/deployments/{id}/files (list file tree)
 *   GET /v8/deployments/{id}/files/{fileId} (get content, base64)
 * For Git deployments, get file by path: GET /v8/deployments/{id}/files?path=api/health.js
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const token = process.env.VERCEL_TOKEN;
const deploymentId = process.env.VERCEL_DEPLOYMENT_ID;
const teamId = process.env.VERCEL_TEAM_ID;

if (!token) {
  console.error('Set VERCEL_TOKEN (vercel.com → Account → Settings → Tokens).');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const apiDir = path.join(root, 'api');

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

async function getDeploymentId() {
  if (deploymentId) return deploymentId;
  const projectId = getProjectId();
  const q = { limit: '1', target: 'production' };
  if (projectId) q.projectId = projectId;
  const list = await request('GET', '/v6/deployments', q);
  const dep = list.deployments?.[0];
  if (!dep?.uid) throw new Error('No production deployment found. Set VERCEL_DEPLOYMENT_ID or VERCEL_PROJECT_ID.');
  return dep.uid;
}

async function main() {
  const depId = await getDeploymentId();
  console.error('Using deployment:', depId);

  const tree = await request('GET', `/v6/deployments/${depId}/files`);
  const files = collectFiles(tree).filter((f) => f.path.startsWith('api/') && !f.path.startsWith('api/lib/'));
  if (files.length === 0) {
    console.error('No api/*.js files in deployment (file tree may be empty for this deployment type).');
    process.exit(1);
  }

  let saved = 0;
  for (const f of files) {
    const rel = f.path;
    const dest = path.join(root, rel);
    const dir = path.dirname(dest);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    try {
      const content = await request('GET', `/v8/deployments/${depId}/files/${f.uid}`);
      const b64 = content.content ?? content.data ?? content.body;
      const raw = b64 != null ? Buffer.from(b64, 'base64').toString('utf8') : '';
      fs.writeFileSync(dest, raw);
      console.error('Restored', rel);
      saved++;
    } catch (e) {
      console.error('Skip', rel, e.message);
    }
  }

  console.log('Restored', saved, 'files from Vercel deployment', depId);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
