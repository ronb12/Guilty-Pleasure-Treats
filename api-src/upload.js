import { put } from '@vercel/blob';
import { setCors, handleOptions } from '../api/lib/cors.js';

/**
 * POST /api/upload
 */
export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return res.status(503).json({ error: 'Blob storage not configured. Add a Vercel Blob store to the project.' });
  }

  try {
    const body = req.body || {};
    const base64 = body.base64;
    if (!base64 || typeof base64 !== 'string') {
      return res.status(400).json({ error: 'Body must include base64 string' });
    }
    const buffer = Buffer.from(base64, 'base64');
    const pathname = body.pathname || `uploads/${Date.now()}.jpg`;
    const contentType = body.contentType || 'image/jpeg';

    const blob = await put({
      pathname,
      body: buffer,
      access: 'public',
      contentType,
      addRandomSuffix: true,
    });

    return res.status(200).json({ url: blob.url });
  } catch (err) {
    console.error('upload', err);
    return res.status(500).json({ error: 'Upload failed', details: err.message });
  }
}
