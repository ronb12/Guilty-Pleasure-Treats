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
const { trackingDetailIndicatesDelivered } = await import(
  path.join(root, 'api', 'lib', 'completeOrderIfTrackingDelivered.js')
);
const { summaryTextFromUspsTrackingPayload } = await import(path.join(root, 'api', 'lib', 'uspsTrackingApi.js'));

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
const rowWithLabeled = parcelTrackingFieldsFromRow({
  tracking_carrier: 'usps',
  tracking_number: '123',
  tracking_updated_at: new Date('2025-01-15T12:00:00.000Z'),
  parcel_labeled_at: new Date('2025-01-14T10:00:00.000Z'),
});
if (!rowWithLabeled.parcelLabeledAt) fail('parcelLabeledAt');
const empty = parcelTrackingFieldsFromRow({});
if (empty.trackingUrl !== null) fail('empty row url null');
ok('parcelTrackingFieldsFromRow');

// --- trackingDetailIndicatesDelivered
if (!trackingDetailIndicatesDelivered('Delivered to recipient')) fail('should detect delivered');
if (!trackingDetailIndicatesDelivered('  DELIVERED, Front Door ')) fail('should detect delivered casing');
if (!trackingDetailIndicatesDelivered('Your shipment delivery complete')) fail('delivery complete');
if (!trackingDetailIndicatesDelivered('In transit to local hub. Delivered.')) fail('delivered should win over in transit');
if (trackingDetailIndicatesDelivered('Out for delivery')) fail('out for delivery should not complete');
if (trackingDetailIndicatesDelivered('Attempted delivery')) fail('attempted should not complete');
if (trackingDetailIndicatesDelivered('In transit')) fail('in transit alone should not complete');
if (trackingDetailIndicatesDelivered('Not delivered')) fail('not delivered should not complete');
if (trackingDetailIndicatesDelivered('')) fail('empty should not complete');
ok('trackingDetailIndicatesDelivered');

// --- USPS Tracking API payload shape (summary / detail)
const uspsSum = summaryTextFromUspsTrackingPayload({
  TrackResults: {
    TrackInfo: { TrackSummary: 'Delivered, Left with Individual.' },
  },
});
if (!uspsSum.includes('Delivered')) fail(`USPS summary parse: ${uspsSum}`);
const uspsDet = summaryTextFromUspsTrackingPayload({
  statusSummary: 'Out for Delivery',
  status: 'Out for Delivery',
});
if (!uspsDet.includes('Delivery')) fail(`USPS detail parse: ${uspsDet}`);
ok('summaryTextFromUspsTrackingPayload');

// --- Router: webhook + orders detail
const routerPath = path.join(root, 'api', '[[...path]].js');
const router = fs.readFileSync(routerPath, 'utf8');
if (!router.includes("'webhooks/carrier-tracking'")) fail('router missing webhooks/carrier-tracking key');
if (!router.includes('webhooks/carrier-tracking.js')) fail('router missing webhooks module map');
if (!router.includes("'cron/poll-usps-tracking'")) fail('router missing cron poll-usps-tracking key');
ok('api/[[...path]].js routing');

const pollUspsPath = path.join(root, 'api-src', 'cron', 'poll-usps-tracking.js');
if (!fs.existsSync(pollUspsPath)) fail(`missing ${pollUspsPath}`);
const pollUspsSrc = fs.readFileSync(pollUspsPath, 'utf8');
if (!pollUspsSrc.includes('fetchUspsTrackingSummaryText')) fail('poll-usps-tracking should call USPS API');
ok('api-src/cron/poll-usps-tracking.js');

const webhookPath = path.join(root, 'api-src', 'webhooks', 'carrier-tracking.js');
if (!fs.existsSync(webhookPath)) fail(`missing ${webhookPath}`);
const webhookSrc = fs.readFileSync(webhookPath, 'utf8');
if (!webhookSrc.includes('CARRIER_TRACKING_WEBHOOK_SECRET')) fail('webhook missing secret env');
if (!webhookSrc.includes('crypto.timingSafeEqual')) fail('webhook should use timing-safe compare');
if (!webhookSrc.includes('completeShippingOrderIfTrackingDelivered')) fail('webhook should auto-complete on delivered text');
ok('api-src/webhooks/carrier-tracking.js');

const orderIdPath = path.join(root, 'api-src', 'orders', 'id.js');
const orderIdSrc = fs.readFileSync(orderIdPath, 'utf8');
if (!orderIdSrc.includes('tracking_carrier')) fail('orders/id missing tracking in SELECT/PATCH');
if (!orderIdSrc.includes('parcelTrackingFieldsFromRow')) fail('orders/id missing parcel helper');
if (!orderIdSrc.includes('shippingReadyTrackingRule')) fail('orders/id missing shipping ready tracking rule');
if (!orderIdSrc.includes('completeShippingOrderIfTrackingDelivered')) fail('orders/id missing auto-complete from tracking');
ok('api-src/orders/id.js');

const shipRulePath = path.join(root, 'api', 'lib', 'shippingReadyTrackingRule.js');
if (!fs.existsSync(shipRulePath)) fail(`missing ${shipRulePath}`);
const shipRuleSrc = fs.readFileSync(shipRulePath, 'utf8');
if (!shipRuleSrc.includes('export function isReadyPickupStatus')) fail('shippingReadyTrackingRule.js should export ESM helpers');
ok('api/lib/shippingReadyTrackingRule.js');

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
