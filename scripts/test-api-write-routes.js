#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const vercelServicePath = path.join(
  root,
  'Guilty Pleasure Treats',
  'Guilty Pleasure Treats',
  'Services',
  'VercelService.swift'
);
const routerPath = path.join(root, 'api', '[[...path]].js');

function fail(msg) {
  console.error(`\n[api-write-routes] ${msg}\n`);
  process.exit(1);
}

if (!fs.existsSync(vercelServicePath)) fail(`Missing ${vercelServicePath}`);
if (!fs.existsSync(routerPath)) fail(`Missing ${routerPath}`);

const service = fs.readFileSync(vercelServicePath, 'utf8');
const router = fs.readFileSync(routerPath, 'utf8');

// Ensure id-based write methods use explicit id route helper.
const requiredExplicitCalls = [
  'apiIDURL(resource: "products", id: id)',
  'apiIDURL(resource: "contact", id: id)',
  'apiIDURL(resource: "contact", id: messageId, tailPathComponents: ["reply"])',
  'apiIDURL(resource: "promotions", id: id)',
  'apiIDURL(resource: "custom-cake-orders", id: id)',
  'apiIDURL(resource: "ai-cake-designs", id: id)',
  'apiIDURL(resource: "customers", id: id)',
  'apiIDURL(resource: "cake-gallery", id: id)',
  'apiIDURL(resource: "events", id: id)',
  'apiIDURL(resource: "product-categories", id: id)',
];
for (const snippet of requiredExplicitCalls) {
  if (!service.includes(snippet)) {
    fail(`Expected explicit id route usage missing: ${snippet}`);
  }
}

// Guard against reintroducing dynamic /<id> write URLs.
const forbiddenDynamicWritePatterns = [
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/products\/\\\(id\\\)"\)\)/,
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/contact\/\\\(id\\\)"\)\)/,
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/promotions\/\\\(id\\\)"\)\)/,
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/custom-cake-orders\/\\\(id\\\)"\)\)/,
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/ai-cake-designs\/\\\(id\\\)"\)\)/,
  /var req = URLRequest\(url: base\.appendingPathComponent\("api\/customers\/\\\(id\\\)"\)\)/,
  /let url = base\.appendingPathComponent\("api\/events\/\\\(id\\\)"\)/,
  /let url = base\.appendingPathComponent\("api\/cake-gallery\/\\\(id\\\)"\)/,
  /let url = base\.appendingPathComponent\("api\/product-categories\/\\\(id\\\)"\)/,
];
for (const pattern of forbiddenDynamicWritePatterns) {
  if (pattern.test(service)) {
    fail(`Forbidden dynamic write URL pattern found: ${pattern}`);
  }
}

// Ensure router supports explicit id endpoints for those resources.
const requiredRouterIdKeys = [
  "key = 'products/id'",
  "key = 'contact/id'",
  "key = 'promotions/id'",
  "key = 'custom-cake-orders/id'",
  "key = 'ai-cake-designs/id'",
  "key = 'customers/id'",
  "key = 'cake-gallery/id'",
  "key = 'product-categories/id'",
  "key = 'events/id'",
];
for (const keySnippet of requiredRouterIdKeys) {
  if (!router.includes(keySnippet)) {
    fail(`Router missing id mapping snippet: ${keySnippet}`);
  }
}

console.log('[api-write-routes] OK');

