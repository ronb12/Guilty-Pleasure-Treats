import assert from 'node:assert/strict';
import { computeOrderTotals } from '../api-src/lib/orderTotals.js';

function cents(n) {
  return Math.round(Number(n) * 100);
}

function assertThrows(fn, messageIncludes = '') {
  let threw = false;
  try {
    fn();
  } catch (err) {
    threw = true;
    if (messageIncludes) {
      const msg = String(err?.message ?? err);
      assert.ok(msg.includes(messageIncludes), `Expected error to include "${messageIncludes}", got "${msg}"`);
    }
  }
  assert.ok(threw, 'Expected function to throw');
}

// Delivery scenario
{
  const totals = computeOrderTotals({
    discountedSubtotal: 10.00,
    totalClient: 17.80, // 10 + 0.80 tax + 2.00 tip + 5.00 delivery
    taxRate: 0.08,
    fulfillmentType: 'Delivery',
    deliveryFee: 5.00,
    shippingFee: 8.00,
  });
  assert.equal(totals.taxCents, cents(0.80));
  assert.equal(totals.feesCents, cents(5.00));
  assert.equal(totals.tipCentsInferred, cents(2.00));
  assert.equal(totals.totalServerCents, cents(17.80));
}

// Shipping scenario
{
  const totals = computeOrderTotals({
    discountedSubtotal: 10.00,
    totalClient: 20.30, // 10 + 0.80 tax + 1.50 tip + 8.00 shipping
    taxRate: 0.08,
    fulfillmentType: 'Shipping',
    deliveryFee: 5.00,
    shippingFee: 8.00,
  });
  assert.equal(totals.taxCents, cents(0.80));
  assert.equal(totals.feesCents, cents(8.00));
  assert.equal(totals.tipCentsInferred, cents(1.50));
  assert.equal(totals.totalServerCents, cents(20.30));
}

// Rounding behavior (cents math)
{
  const totals = computeOrderTotals({
    discountedSubtotal: 10.01,
    totalClient: 15.99, // choose a value that yields non-negative tip; fees=0 for Pickup
    taxRate: 0.08,
    fulfillmentType: 'Pickup',
    deliveryFee: 5.00,
    shippingFee: 8.00,
  });
  assert.ok(totals.taxCents >= 0);
  assert.ok(totals.tipCentsInferred >= 0);
}

// Invalid fulfillment type
assertThrows(
  () =>
    computeOrderTotals({
      discountedSubtotal: 10.0,
      totalClient: 10.0,
      taxRate: 0.08,
      fulfillmentType: 'DroneDelivery',
      deliveryFee: 5.0,
      shippingFee: 8.0,
    }),
  'Invalid fulfillmentType'
);

// Negative fee should throw
assertThrows(
  () =>
    computeOrderTotals({
      discountedSubtotal: 10.0,
      totalClient: 10.0,
      taxRate: 0.08,
      fulfillmentType: 'Delivery',
      deliveryFee: -1.0,
      shippingFee: 8.0,
    }),
  'deliveryFee must be non-negative'
);

// Tip inferred negative should throw
assertThrows(
  () =>
    computeOrderTotals({
      discountedSubtotal: 10.0,
      totalClient: 15.0, // too low: 10 + tax(0.8) + fees(5.0) = 15.8
      taxRate: 0.08,
      fulfillmentType: 'Delivery',
      deliveryFee: 5.0,
      shippingFee: 8.0,
    }),
  'Inferred tip must be non-negative'
);

console.log('test-order-totals: OK');

