/**
 * Server-side low-inventory admin push when stock crosses into the same state as
 * Swift `Product.showsAdminLowStockBadge` (tracked, threshold set, 0 < qty <= threshold).
 */

/** @param {unknown} stockQuantity @param {unknown} threshold */
export function isAdminLowStockState(stockQuantity, threshold) {
  if (stockQuantity == null || threshold == null) return false;
  const q = Number(stockQuantity);
  const t = Number(threshold);
  if (!Number.isFinite(q) || !Number.isFinite(t)) return false;
  if (q <= 0) return false;
  return q <= t;
}

/**
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 * @param {{ stock_quantity?: unknown; low_stock_threshold?: unknown } | null} previousRow
 * @param {{ id?: unknown; name?: unknown; stock_quantity?: unknown; low_stock_threshold?: unknown }} updatedRow
 */
export async function notifyAdminsWhenStockBecomesLow(sql, previousRow, updatedRow) {
  if (!sql || !updatedRow) return;
  const was =
    previousRow &&
    isAdminLowStockState(previousRow.stock_quantity, previousRow.low_stock_threshold);
  const now = isAdminLowStockState(updatedRow.stock_quantity, updatedRow.low_stock_threshold);
  if (!now || was) return;
  try {
    const { isApnsConfigured, notifyLowInventory } = await import('./apns.js');
    if (!isApnsConfigured()) return;
    const adminRows = await sql`
      SELECT device_token FROM push_tokens
      WHERE is_admin = true AND device_token IS NOT NULL AND TRIM(device_token) != ''
    `;
    const tokens = (adminRows || []).map((r) => r.device_token).filter(Boolean);
    if (!tokens.length) return;
    const pid = updatedRow.id != null ? String(updatedRow.id) : '';
    const name = updatedRow.name != null ? String(updatedRow.name) : '';
    const q = Number(updatedRow.stock_quantity);
    const t = Number(updatedRow.low_stock_threshold);
    await notifyLowInventory(tokens, pid, name, q, t);
  } catch (e) {
    console.warn('[notifyAdminLowStock]', e?.message ?? e);
  }
}
