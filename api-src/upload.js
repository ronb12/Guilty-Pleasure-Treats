import { put } from '@vercel/blob';
import { setCors, handleOptions } from '../api/lib/cors.js';
import multiparty from 'multiparty';
import fs from 'fs';

/**
 * POST /api/upload
 * Accepts:
 * 1) multipart/form-data with "file" or "image" field (recommended) and optional "pathname" field
 * 2) application/json with { base64: string, pathname?: string, contentType?: string }
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

  const contentType = (req.headers && req.headers['content-type']) || '';
  const isMultipart = contentType.includes('multipart/form-data');

  try {
    let buffer;
    let pathname = `uploads/${Date.now()}.jpg`;
    let contentTypeHeader = 'image/jpeg';

    if (isMultipart) {
      const { fields, files } = await new Promise((resolve, reject) => {
        const form = new multiparty.Form();
        form.parse(req, (err, fields, files) => {
          if (err) reject(err);
          else resolve({ fields, files });
        });
      });

      const file = (files.file && files.file[0]) || (files.image && files.image[0]);
      if (!file || !file.path) {
        return res.status(400).json({ error: 'No file in multipart form. Use field name "file" or "image".' });
      }
      const rawPath = (fields.pathname && fields.pathname[0]) ? fields.pathname[0] : pathname;
      pathname = typeof rawPath === 'string' ? rawPath.trim() : pathname;
      if (typeof pathname === 'string' && !pathname.endsWith('.jpg') && !pathname.endsWith('.jpeg') && !pathname.endsWith('.png')) {
        pathname = pathname.replace(/\?.*$/, '') + '.jpg';
      }
      buffer = fs.readFileSync(file.path);
      if (file.headers && file.headers['content-type']) {
        contentTypeHeader = file.headers['content-type'].split(';')[0].trim();
      }
      try { fs.unlinkSync(file.path); } catch (_) {}
    } else {
      const body = req.body || {};
      const base64 = body.base64;
      if (!base64 || typeof base64 !== 'string') {
        return res.status(400).json({ error: 'Body must include base64 string, or use multipart/form-data with "file" field.' });
      }
      buffer = Buffer.from(base64, 'base64');
      const rawPath = body.pathname;
      pathname = typeof rawPath === 'string' ? rawPath.trim() : (Array.isArray(rawPath) && rawPath[0] != null ? String(rawPath[0]).trim() : pathname);
      contentTypeHeader = body.contentType || 'image/jpeg';
    }

    pathname = (typeof pathname === 'string' && pathname.trim()) ? pathname.trim() : `uploads/${Date.now()}.jpg`;
    pathname = String(pathname);

    const blob = await put(pathname, buffer, {
      access: 'public',
      contentType: contentTypeHeader,
      addRandomSuffix: true,
    });

    return res.status(200).json({ url: blob.url });
  } catch (err) {
    console.error('upload', err);
    return res.status(500).json({ error: 'Upload failed', details: err.message });
  }
}
