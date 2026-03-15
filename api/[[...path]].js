/**
 * Single catch-all API route for Vercel Hobby (12 function limit).
 * Routes /api/* to the corresponding handler in api-src/.
 */
import indexHandler from '../api-src/index.js';
import healthHandler from '../api-src/health.js';
import uploadHandler from '../api-src/upload.js';
import productsHandler from '../api-src/products.js';
import productIdHandler from '../api-src/products/id.js';
import ordersHandler from '../api-src/orders.js';
import orderIdHandler from '../api-src/orders/id.js';
import authLogin from '../api-src/auth/login.js';
import authSignup from '../api-src/auth/signup.js';
import authMe from '../api-src/auth/me.js';
import authLogout from '../api-src/auth/logout.js';
import authApple from '../api-src/auth/apple.js';
import usersMe from '../api-src/users/me.js';
import settingsBusiness from '../api-src/settings/business.js';
import promotionsIndex from '../api-src/promotions/index.js';
import promotionsCode from '../api-src/promotions/code/code.js';
import promotionsId from '../api-src/promotions/id.js';
import customCakeOrdersIndex from '../api-src/custom-cake-orders/index.js';
import customCakeOrdersId from '../api-src/custom-cake-orders/id.js';
import aiCakeDesignsIndex from '../api-src/ai-cake-designs/index.js';
import aiCakeDesignsId from '../api-src/ai-cake-designs/id.js';
import customCakeOptions from '../api-src/custom-cake-options/index.js';
import settingsCustomCakeOptions from '../api-src/settings/custom-cake-options.js';

const routes = {
  '': indexHandler,
  health: healthHandler,
  upload: uploadHandler,
  products: productsHandler,
  'products/id': productIdHandler,
  orders: ordersHandler,
  'orders/id': orderIdHandler,
  'auth/login': authLogin,
  'auth/signup': authSignup,
  'auth/me': authMe,
  'auth/logout': authLogout,
  'auth/apple': authApple,
  'users/me': usersMe,
  'settings/business': settingsBusiness,
  'promotions': promotionsIndex,
  'promotions/code/code': promotionsCode,
  'promotions/id': promotionsId,
  'custom-cake-orders': customCakeOrdersIndex,
  'custom-cake-orders/id': customCakeOrdersId,
  'ai-cake-designs': aiCakeDesignsIndex,
  'ai-cake-designs/id': aiCakeDesignsId,
  'custom-cake-options': customCakeOptions,
  'settings/custom-cake-options': settingsCustomCakeOptions,
};

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

export default async function handler(req, res) {
  await readBody(req);
  if (typeof req.body === 'string') {
    try {
      req.body = req.body ? JSON.parse(req.body) : {};
    } catch {
      req.body = {};
    }
  }
  if (req.body == null) req.body = {};
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
  }

  req.query = q;
  const fn = routes[key];
  if (!fn) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  return fn(req, res);
}
