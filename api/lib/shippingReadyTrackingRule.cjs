'use strict';

/**
 * Shipping fulfillment: require UPS/FedEx/USPS + tracking number before status becomes "ready"
 * (app label "Ready for Pickup" — the step when parcel has shipped).
 */

function isReadyPickupStatus(status) {
  const s = String(status ?? '').trim().toLowerCase();
  return s === 'ready' || s === 'ready for pickup';
}

function isShippingFulfillmentType(fulfillmentType) {
  return String(fulfillmentType ?? '').trim().toLowerCase() === 'shipping';
}

function hasValidParcelTracking(carrier, number) {
  const c = carrier != null ? String(carrier).trim().toLowerCase() : '';
  const n = number != null ? String(number).trim() : '';
  if (!c || !n) return false;
  return c === 'ups' || c === 'fedex' || c === 'usps';
}

/** Apply optional PATCH body tracking keys onto current row (same semantics as orders/id PATCH). */
function effectiveTrackingAfterPatch(body, row) {
  const b = body || {};
  let carrier = row?.tracking_carrier ?? null;
  let number = row?.tracking_number ?? null;
  if ('trackingCarrier' in b || 'tracking_carrier' in b) {
    const v = b.trackingCarrier ?? b.tracking_carrier;
    carrier =
      v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim().toLowerCase();
  }
  if ('trackingNumber' in b || 'tracking_number' in b) {
    const v = b.trackingNumber ?? b.tracking_number;
    number = v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim();
  }
  return { carrier, number };
}

function shippingReadyRequiresTrackingError() {
  return {
    error:
      'Shipping orders need a carrier and tracking number before they can be marked ready. Save parcel tracking first, or include trackingCarrier and trackingNumber in the same request.',
  };
}

module.exports = {
  isReadyPickupStatus,
  isShippingFulfillmentType,
  hasValidParcelTracking,
  effectiveTrackingAfterPatch,
  shippingReadyRequiresTrackingError,
};
