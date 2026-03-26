/**
 * ESM re-export for handlers that use `import` (e.g. orders/id.js).
 * Implementation lives in shippingReadyTrackingRule.cjs for CommonJS callers.
 */
export {
  isReadyPickupStatus,
  isShippingFulfillmentType,
  hasValidParcelTracking,
  effectiveTrackingAfterPatch,
  shippingReadyRequiresTrackingError,
} from './shippingReadyTrackingRule.cjs';
