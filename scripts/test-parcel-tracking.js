#!/usr/bin/env node
/**
 * Parcel tracking: unit tests (URLs + JSON shape) and static checks (router + Swift client).
 * No database required. Run: node scripts/test-parcel-tracking.js
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

function fail(msg) {
  console.error(`\n[parcel-tracking] FAIL: ${msg}\n`);
  process.exit(1);
}

function ok(label) {
  console.log(`[parcel-tracking] OK  ${label}`);
}

const { normalizeTrackingCarrier, carrierTrackingUrl, parcelTrackingFieldsFromRow } = await import(
  path.join(root, 'api', 'lib', 'parcelTrackingUrls.js')
);

// --- normalizeTrackingCarrier
if (normalizeTrackingCarrier('UPS') !== 'ups') fail('normalize UPS');
if (normalizeTrackingCarrier('FedEx') !== 'fedex') fail('normalize FedEx');
if (normalizeTrackingCarrier('fed-ex') !== 'fedex') fail('normalize fed-ex');
if (normalizeTrackingCarrier('USPS') !== 'usps') fail('normalize USPS');
if (normalizeTrackingCarrier('  ') !== null) fail('normalize empty');
if (normalizeTrackingCarrier('dhl') !== null) fail('unknown carrier should be null');
ok('normalizeTrackingCarrier');

// --- carrierTrackingUrl
const upsUrl = carrierTrackingUrl('ups', '1Z999AA10123456784');
if (!upsUrl || !upsUrl.includes('ups.com') || !upsUrl.includes(encodeURIComponent('1Z999AA10123456784'))) {
  fail(`UPS URL unexpected: ${upsUrl}`);
}
const fedexUrl = carrierTrackingUrl('fedex', '123456789012');
if (!fedexUrl || !fedexUrl.includes('fedex.com')) fail(`FedEx URL unexpected: ${fedexUrl}`);
const uspsUrl = carrierTrackingUrl('usps', '9400111899223344556677');
if (!uspsUrl || !uspsUrl.includes('usps.com')) fail(`USPS URL unexpected: ${uspsUrl}`);
if (carrierTrackingUrl('ups', '') !== null) fail('empty number');
if (carrierTrackingUrl('ups', '   ') !== null) fail('whitespace number');
if (carrierTrackingUrl('dhl', '123') !== null) fail('invalid carrier no URL');
ok('carrierTrackingUrl');

// --- parcelTrackingFieldsFromRow
const row = {
  tracking_carrier: 'UPS',
  tracking_number: '1ZTEST',
  tracking_status_detail: ' In transit ',
  tracking_updated_at: new Date('2025-01-15T12:00:00.000Z'),
};
const fields = parcelTrackingFieldsFromRow(row);
if (fields.trackingCarrier !== 'ups') fail('row carrier lowercase');
if (fields.trackingNumber !== '1ZTEST') fail('row number');
if (fields.trackingStatusDetail !== 'In transit') fail('row detail trim');
if (!fields.trackingUpdatedAt) fail('row updated at');
if (!fields.trackingUrl) fail('row url');
const empty = parcelTrackingFieldsFromRow({});
if (empty.trackingUrl !== null) fail('empty row url null');
ok('parcelTrackingFieldsFromRow');

// --- Router: webhook + orders detail
const routerPath = path.join(root, 'api', '[[...path]].js');
const router = fs.readFileSync(routerPath, 'utf8');
if (!router.includes("'webhooks/carrier-tracking'")) fail('router missing webhooks/carrier-tracking key');
if (!router.includes('webhooks/carrier-tracking.js')) fail('router missing webhooks module map');
ok('api/[[...path]].js routing');

const webhookPath = path.join(root, 'api-src', 'webhooks', 'carrier-tracking.js');
if (!fs.existsSync(webhookPath)) fail(`missing ${webhookPath}`);
const webhookSrc = fs.readFileSync(webhookPath, 'utf8');
if (!webhookSrc.includes('CARRIER_TRACKING_WEBHOOK_SECRET')) fail('webhook missing secret env');
if (!webhookSrc.includes('crypto.timingSafeEqual')) fail('webhook should use timing-safe compare');
ok('api-src/webhooks/carrier-tracking.js');

const orderIdPath = path.join(root, 'api-src', 'orders', 'id.js');
const orderIdSrc = fs.readFileSync(orderIdPath, 'utf8');
if (!orderIdSrc.includes('tracking_carrier')) fail('orders/id missing tracking in SELECT/PATCH');
if (!orderIdSrc.includes('parcelTrackingFieldsFromRow')) fail('orders/id missing parcel helper');
ok('api-src/orders/id.js');

// --- Swift client
const vercelServicePath = path.join(
  root,
  'Guilty Pleasure Treats',
  'Guilty Pleasure Treats',
  'Services',
  'VercelService.swift'
);
const swift = fs.readFileSync(vercelServicePath, 'utf8');
if (!swift.includes('func fetchOrder(orderId:')) fail('VercelService missing fetchOrder');
if (!swift.includes('func updateOrderParcelTracking(')) fail('VercelService missing updateOrderParcelTracking');
if (!swift.includes('apiIDURL(resource: "orders", id: orderId)')) fail('VercelService orders should use apiIDURL');
ok('VercelService.swift');

const orderModelPath = path.join(
  root,
  'Guilty Pleasure Treats',
  'Guilty Pleasure Treats',
  'Models',
  'Order.swift'
);
const orderSwift = fs.readFileSync(orderModelPath, 'utf8');
for (const key of ['trackingCarrier', 'trackingNumber', 'trackingUrl']) {
  if (!orderSwift.includes(key)) fail(`Order.swift missing ${key}`);
}
ok('Order.swift');

console.log('\n[parcel-tracking] All checks passed.\n');
