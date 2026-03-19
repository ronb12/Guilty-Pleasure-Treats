/**
 * Server-side promotion validation (matches client discount math).
 */

export function promotionRowToDiscount(row, itemsSubtotalDollars) {
  if (!row || !row.is_active) return null;
  const now = new Date();
  if (row.valid_from && new Date(row.valid_from) > now) return null;
  if (row.valid_to && new Date(row.valid_to) < now) return null;
  const sub = Number(itemsSubtotalDollars);
  if (!Number.isFinite(sub) || sub < 0) return null;
  const type = String(row.discount_type ?? '').toLowerCase();
  const value = Number(row.value ?? 0);
  if (!Number.isFinite(value) || value < 0) return null;
  if (type.includes('percent')) {
    return sub * (value / 100);
  }
  if (type.includes('fixed')) {
    return Math.min(value, sub);
  }
  return null;
}

