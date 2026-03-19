/**
 * Single catch-all API route for Vercel Hobby (12 function limit).
 * Routes /api/* to the corresponding handler in api-src/.
 * Uses dynamic import so handlers (and their deps) load only when needed, avoiding startup crashes.
 */
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API_SRC = path.resolve(__dirname, '..', 'api-src');

function modulePathFor(key) {
  const fileMap = {
    '': 'index.js',
    health: 'health.js',
    upload: 'upload.js',
    products: 'products.js',
    'products/id': 'products/id.js',
    orders: 'orders.js',
    'orders/id': 'orders/id.js',
    'auth/login': 'auth/login.js',
    'auth/signup': 'auth/signup.js',
    'auth/me': 'auth/me.js',
    'auth/logout': 'auth/logout.js',
    'auth/apple': 'auth/apple.js',
    'auth/set-password': 'auth/set-password.js',
    'auth/forgot-password': 'auth/forgot-password.js',
    'auth/reset-password': 'auth/reset-password.js',
    'auth/delete-account': 'auth/delete-account.js',
    'users/me': 'users/me.js',
    'settings/business': 'settings/business.js',
    'settings/business-hours': 'settings/business-hours.js',
    promotions: 'promotions/index.js',
    'promotions/code/code': 'promotions/code/code.js',
    'promotions/id': 'promotions/id.js',
    'custom-cake-orders': 'custom-cake-orders/index.js',
    'custom-cake-orders/id': 'custom-cake-orders/id.js',
    'ai-cake-designs': 'ai-cake-designs/index.js',
    'ai-cake-designs/id': 'ai-cake-designs/id.js',
    'custom-cake-options': 'custom-cake-options/index.js',
    'settings/custom-cake-options': 'settings/custom-cake-options.js',
    contact: 'contact/index.js',
    'contact/id': 'contact/id.js',
    'contact/id/reply': 'contact/reply.js',
    'contact/replies': 'contact/replies.js',
    'admin-messages': 'admin-messages.js',
    'stripe/create-checkout-session': 'stripe/create-checkout-session.js',
    'stripe/create-payment-intent': 'stripe/create-payment-intent.js',
    'ai/generate-image': 'ai/generate-image.js',
    'cake-gallery': 'cake-gallery/index.js',
    'cake-gallery/id': 'cake-gallery/id.js',
    'product-categories': 'product-categories/index.js',
    'product-categories/id': 'product-categories/id.js',
    customers: 'customers/index.js',
    'customers/id': 'customers/id.js',
    'push/register': 'push/register.js',
    'analytics/summary': 'analytics/summary.js',
    reviews: 'reviews/index.js',
    events: 'events/index.js',
    'events/id': 'events/id.js',
  };
  const file = fileMap[key];
  if (!file) return null;
  const fullPath = path.join(API_SRC, file);
  return pathToFileURL(fullPath).href;
}

const BODY_READ_TIMEOUT_MS = 8000;

function readBody(req) {
  return new Promise((resolve) => {
    if (req.body != null && typeof req.body === 'object') {
      resolve();
      return;
    }
    const method = (req.method || '').toUpperCase();
    if (!['POST', 'PUT', 'PATCH'].includes(method)) {
      req.body = req.body || {};
      resolve();
      return;
    }
    const timeout = setTimeout(() => {
      req.body = {};
      resolve();
    }, BODY_READ_TIMEOUT_MS);
    const done = () => {
      clearTimeout(timeout);
      resolve();
    };
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const contentType = (req.headers && req.headers['content-type']) || '';
      if (contentType.includes('application/json') && chunks.length) {
        try {
          req.body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        } catch {
          req.body = {};
        }
      } else {
        req.body = req.body || {};
      }
      done();
    });
    req.on('error', () => {
      req.body = {};
      done();
    });
  });
}

function getPathKey(req) {
  let rawPath = req.query.path;
  if (typeof rawPath === 'string' && rawPath.startsWith('[[')) rawPath = null;
  if (rawPath == null) {
    let pathname = '';
    if (req.url) pathname = (req.url.split('?')[0] || '').replace(/^\/api\/?/, '');
    if (!pathname || pathname.startsWith('[[')) {
      const xUrl = req.headers['x-url'] || req.headers['x-invoke-path'] || req.headers['x-vercel-url'];
      if (xUrl) pathname = (String(xUrl).split('?')[0] || '').replace(/^\/api\/?/, '');
    }
    rawPath = pathname ? pathname.split('/').filter(Boolean) : [];
  }
  if (typeof rawPath === 'string') {
    try {
      rawPath = decodeURIComponent(rawPath).split('/').filter(Boolean);
    } catch {
      rawPath = rawPath.split('/').filter(Boolean);
    }
  }
  const segs = Array.isArray(rawPath) ? rawPath.filter(Boolean) : [];

  let key = '';
  const q = { ...req.query };
  delete q.path;

  if (segs.length === 0) {
    key = '';
  } else if (segs[0] === 'health') {
    key = 'health';
  } else if (segs[0] === 'upload') {
    key = 'upload';
  } else if (segs[0] === 'products') {
    if (segs.length === 1) key = 'products';
    else { key = 'products/id'; q.id = segs[1]; }
  } else if (segs[0] === 'orders') {
    if (segs.length === 1) key = 'orders';
    else { key = 'orders/id'; q.id = segs[1]; }
  } else if (segs[0] === 'auth' && segs[1]) {
    key = `auth/${segs[1]}`;
  } else if (segs[0] === 'users' && segs[1] === 'me') {
    key = 'users/me';
  } else if (segs[0] === 'settings' && segs[1] === 'business') {
    key = 'settings/business';
  } else if (segs[0] === 'settings' && segs[1] === 'business-hours') {
    key = 'settings/business-hours';
  } else if (segs[0] === 'promotions') {
    if (segs.length === 1) key = 'promotions';
    else if (segs[1] === 'code' && segs[2]) { key = 'promotions/code/code'; q.code = segs[2]; }
    else { key = 'promotions/id'; q.id = segs[1]; }
  } else if (segs[0] === 'custom-cake-orders') {
    if (segs.length === 1) key = 'custom-cake-orders';
    else { key = 'custom-cake-orders/id'; q.id = segs[1]; }
  } else if (segs[0] === 'ai-cake-designs') {
    if (segs.length === 1) key = 'ai-cake-designs';
    else { key = 'ai-cake-designs/id'; q.id = segs[1]; }
  } else if (segs[0] === 'custom-cake-options') {
    key = 'custom-cake-options';
  } else if (segs[0] === 'settings' && segs[1] === 'custom-cake-options') {
    key = 'settings/custom-cake-options';
  } else if (segs[0] === 'contact') {
    if (segs.length === 1) key = 'contact';
    else if (segs[1] === 'replies') key = 'contact/replies';
    else if (segs.length >= 3 && segs[2] === 'reply') {
      key = 'contact/id/reply';
      q.id = segs[1];
    } else {
      key = 'contact/id';
      q.id = segs[1];
    }
  } else if (segs[0] === 'admin-messages') {
    key = 'admin-messages';
  } else if (segs[0] === 'stripe' && segs[1] === 'create-checkout-session') {
    key = 'stripe/create-checkout-session';
  } else if (segs[0] === 'stripe' && segs[1] === 'create-payment-intent') {
    key = 'stripe/create-payment-intent';
  } else if (segs[0] === 'ai' && segs[1] === 'generate-image') {
    key = 'ai/generate-image';
  } else if (segs[0] === 'cake-gallery') {
    if (segs.length === 1) key = 'cake-gallery';
    else { key = 'cake-gallery/id'; q.id = segs[1]; }
  } else if (segs[0] === 'product-categories') {
    if (segs.length === 1) key = 'product-categories';
    else { key = 'product-categories/id'; q.id = segs[1]; }
  } else if (segs[0] === 'customers') {
    if (segs.length === 1) key = 'customers';
    else { key = 'customers/id'; q.id = segs[1]; }
  } else if (segs[0] === 'push' && segs[1] === 'register') {
    key = 'push/register';
  } else if (segs[0] === 'analytics' && segs[1] === 'summary') {
    key = 'analytics/summary';
  } else if (segs[0] === 'reviews') {
    key = 'reviews';
  } else if (segs[0] === 'events') {
    if (segs.length === 1) key = 'events';
    else { key = 'events/id'; q.id = segs[1]; }
  }
  return { key, q };
}

export default async function handler(req, res) {
  const pathResult = getPathKey(req);
  const key = pathResult.key;
  req.query = pathResult.q;

  const contentType = (req.headers && req.headers['content-type']) || '';
  const isUploadMultipart = key === 'upload' && (req.method || '').toUpperCase() === 'POST' && contentType.includes('multipart/form-data');

  if (!isUploadMultipart) {
    await readBody(req);
    if (typeof req.body === 'string') {
      try {
        req.body = req.body ? JSON.parse(req.body) : {};
      } catch {
        req.body = {};
      }
    }
    if (req.body == null) req.body = {};
  } else {
    req.body = {};
  }

  // Inline health so we never fail on import (no db/neon loaded)
  if (key === 'health') {
    res.setHeader('Content-Type', 'application/json');
    res.status(200).json({
      ok: true,
      service: 'Guilty Pleasure Treats API',
      database: !!(process.env.POSTGRES_URL || process.env.DATABASE_URL),
      timestamp: new Date().toISOString(),
    });
    return;
  }

  const modulePath = modulePathFor(key);
  if (!modulePath) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  try {
    const mod = await import(modulePath);
    const fn = mod.default;
    if (typeof fn !== 'function') {
      if (!res.headersSent) res.status(500).json({ error: 'A server error occurred. Please try again.' });
      return;
    }
    const result = fn(req, res);
    if (result && typeof result.catch === 'function') {
      return result.catch((err) => {
        console.error('Route handler error', key, err);
        if (!res.headersSent) res.status(500).json({ error: 'A server error occurred. Please try again.' });
      });
    }
    return result;
  } catch (err) {
    console.error('Route handler error', key, err);
    if (!res.headersSent) res.status(500).json({ error: 'A server error occurred. Please try again.' });
  }
}
