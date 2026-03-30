/**
 * POST /api/upload — Admin: store file in Vercel Blob.
 * JSON body: { base64: string, pathname: string, contentType?: string }
 * Returns { url: string }.
 */
import { put } from '@vercel/blob';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';
import { setCors, handleOptions } from '../api/lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (session.isAdmin !== true) return res.status(403).json({ error: 'Admin required' });

  const blobToken = process.env.BLOB_READ_WRITE_TOKEN;
  if (!blobToken) {
    return res.status(503).json({ error: 'File upload is not configured (BLOB_READ_WRITE_TOKEN).' });
  }

  const body = req.body || {};
  let b64 = body.base64;
  if (!b64 || typeof b64 !== 'string') {
    return res.status(400).json({ error: 'base64 is required' });
  }
  b64 = b64.trim();
  const dataUrl = b64.match(/^data:([^;]+);base64,(.+)$/i);
  if (dataUrl) b64 = dataUrl[2];
  b64 = b64.replace(/\s/g, '');
  let buf;
  try {
    buf = Buffer.from(b64, 'base64');
  } catch {
    return res.status(400).json({ error: 'Invalid base64' });
  }
  if (!buf.length) {
    return res.status(400).json({ error: 'Invalid base64 (empty after decode)' });
  }
  if (buf.length > 4_200_000) {
    return res.status(400).json({ error: 'File too large (max ~4MB)' });
  }
  const pathname = String(body.pathname || `uploads/${Date.now()}`)
    .replace(/\.\./g, '')
    .replace(/^\/+/, '');
  const contentType = String(body.contentType || 'image/jpeg').slice(0, 120);

  try {
    const blob = await put(pathname, buf, {
      access: 'public',
      token: blobToken,
      contentType,
    });
    return res.status(200).json({ url: blob.url });
  } catch (err) {
    console.error('[upload]', err);
    return res.status(500).json({ error: err?.message || 'Upload failed' });
  }
}
