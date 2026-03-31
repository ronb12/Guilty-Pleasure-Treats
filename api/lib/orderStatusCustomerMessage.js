/**
 * Customer-facing copy for order status notifications (not raw DB strings).
 */

/**
 * @param {unknown} statusRaw — e.g. "Ready for Pickup", "Completed"
 * @param {unknown} fulfillmentTypeRaw — Pickup | Delivery | Shipping
 */
export function customerOrderStatusMessage(statusRaw, fulfillmentTypeRaw) {
  const s = String(statusRaw ?? '').trim().toLowerCase();
  const ft = String(fulfillmentTypeRaw ?? '').trim().toLowerCase();

  if (s === 'ready' || s === 'ready for pickup') {
    if (ft === 'shipping') {
      return 'Shipped — your order is on the way. Open the app to track your package.';
    }
    if (ft === 'delivery') {
      return 'Out for delivery — your order is on the way.';
    }
    return 'Ready for pickup — see you soon!';
  }
  if (s === 'delivered') {
    return 'Delivered — enjoy your treats!';
  }
  if (s === 'completed') {
    return 'Order complete — thanks for ordering!';
  }
  if (s === 'pending') return 'We received your order.';
  if (s === 'confirmed') return 'Your order is confirmed.';
  if (s === 'preparing' || s === 'in_progress') return 'We are preparing your order.';
  if (s === 'cancelled') return 'Your order was cancelled.';

  const pretty = String(statusRaw ?? 'Updated').replace(/_/g, ' ');
  return `Update: ${pretty}. Tap to view your order.`;
}
