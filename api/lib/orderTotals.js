/**
 * Order totals helper (server-side authoritative).
 *
 * Goal: compute/validate tax + delivery/shipping fees + total from:
 * - discountedSubtotal (client-provided, already after promotions)
 * - business tax rate
 * - business delivery/shipping fees
 * - fulfillment type
 * - client total (used to infer tip)
 */

export function toCents(amount, name = 'amount') {
  const n = Number(amount);
  if (!Number.isFinite(n)) throw new Error(`Invalid ${name}`);
  // Use rounding to avoid fractional-cent drift.
  return Math.round(n * 100);
}

export function fromCents(cents) {
  return cents / 100;
}

export function normalizeFulfillmentType(fulfillmentType) {
  const v = String(fulfillmentType ?? '').trim();
  if (!['Pickup', 'Delivery', 'Shipping'].includes(v)) {
    throw new Error(`Invalid fulfillmentType: ${v}`);
  }
  return v;
}

export function computeOrderTotals({
  discountedSubtotal,
  totalClient,
  taxRate,
  fulfillmentType,
  deliveryFee,
  shippingFee,
}) {
  const discountedSubtotalCents = toCents(discountedSubtotal, 'discountedSubtotal');
  const totalClientCents = toCents(totalClient, 'totalClient');
  const taxRateNum = Number(taxRate);
  if (!Number.isFinite(taxRateNum)) throw new Error('Invalid taxRate');

  const fType = normalizeFulfillmentType(fulfillmentType);

  const deliveryFeeCents = deliveryFee != null ? toCents(deliveryFee, 'deliveryFee') : 0;
  const shippingFeeCents = shippingFee != null ? toCents(shippingFee, 'shippingFee') : 0;

  if (discountedSubtotalCents < 0) throw new Error('discountedSubtotal must be non-negative');
  if (totalClientCents < 0) throw new Error('totalClient must be non-negative');
  if (deliveryFeeCents < 0) throw new Error('deliveryFee must be non-negative');
  if (shippingFeeCents < 0) throw new Error('shippingFee must be non-negative');

  const feesCents = fType === 'Delivery' ? deliveryFeeCents : fType === 'Shipping' ? shippingFeeCents : 0;
  const taxCents = Math.round(discountedSubtotalCents * taxRateNum);

  // Tip is not stored separately; infer it from the client total after fees + tax.
  const tipCentsInferred = totalClientCents - (discountedSubtotalCents + taxCents + feesCents);
  if (tipCentsInferred < 0) throw new Error('Inferred tip must be non-negative');

  const totalServerCents = discountedSubtotalCents + taxCents + feesCents + tipCentsInferred;

  return {
    // Keep cents for exact math; convert to dollars at the API boundary.
    discountedSubtotalCents,
    taxCents,
    feesCents,
    deliveryFeeCents: fType === 'Delivery' ? deliveryFeeCents : 0,
    shippingFeeCents: fType === 'Shipping' ? shippingFeeCents : 0,
    tipCentsInferred,
    totalServerCents,
  };
}

export function orderTotalsToDollars(totals) {
  return {
    subtotal: fromCents(totals.discountedSubtotalCents),
    tax: fromCents(totals.taxCents),
    total: fromCents(totals.totalServerCents),
    deliveryFee: fromCents(totals.deliveryFeeCents),
    shippingFee: fromCents(totals.shippingFeeCents),
    tip: fromCents(totals.tipCentsInferred),
  };
}

