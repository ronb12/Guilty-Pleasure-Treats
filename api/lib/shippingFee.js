/**
 * Shipping fee zones for checkout (local vs nationwide).
 * Address format matches iOS: last line is typically "City, ST, ZIP" or "City, ST ZIP".
 */

const DEFAULT_LOCAL_STATES = ['NJ', 'NY', 'PA', 'CT', 'DE'];

/**
 * @param {string | null | undefined} addr
 * @returns {string | null} Two-letter US state code or null
 */
export function extractStateCodeFromAddress(addr) {
  if (addr == null || typeof addr !== 'string') return null;
  const lines = addr
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length === 0) return null;
  const last = lines[lines.length - 1];
  const parts = last.split(',').map((p) => p.trim());
  if (parts.length >= 2) {
    const m = parts[1].match(/^([A-Za-z]{2})\b/);
    if (m) return m[1].toUpperCase();
  }
  return null;
}

/**
 * @param {object} v - business_settings value_json (merged with defaults)
 * @param {string | null} deliveryAddressClean
 * @returns {number} Shipping fee in dollars (>= 0)
 */
export function resolveShippingFeeDollars(v, deliveryAddressClean) {
  const nationwide = v.shipping_fee != null ? Number(v.shipping_fee) : 0;
  const localRaw = v.shipping_fee_local != null ? Number(v.shipping_fee_local) : nationwide;
  const localFee = Number.isFinite(localRaw) && localRaw >= 0 ? localRaw : nationwide;

  let states = DEFAULT_LOCAL_STATES;
  if (Array.isArray(v.shipping_local_states) && v.shipping_local_states.length > 0) {
    states = v.shipping_local_states.map((s) => String(s).trim().toUpperCase().slice(0, 2)).filter(Boolean);
  } else if (typeof v.shipping_local_states === 'string' && v.shipping_local_states.trim()) {
    states = v.shipping_local_states
      .split(',')
      .map((s) => s.trim().toUpperCase().slice(0, 2))
      .filter(Boolean);
  }
  const localSet = new Set(states.length ? states : DEFAULT_LOCAL_STATES);

  if (!deliveryAddressClean) return Math.max(0, nationwide);

  const st = extractStateCodeFromAddress(deliveryAddressClean);
  if (!st) return Math.max(0, nationwide);

  return Math.max(0, localSet.has(st) ? localFee : nationwide);
}
