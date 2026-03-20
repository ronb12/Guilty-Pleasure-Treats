/**
 * Coerce Postgres / Neon driver values to a real boolean.
 * Avoids JS pitfalls: Boolean("false") === true, Boolean("f") === true.
 */
export function pgBool(val) {
  if (val === true || val === 1) return true;
  if (val === false || val === 0 || val === null || val === undefined) return false;
  if (typeof val === 'string') {
    const s = val.trim().toLowerCase();
    if (s === 't' || s === 'true' || s === '1' || s === 'yes') return true;
    if (s === 'f' || s === 'false' || s === '0' || s === 'no' || s === '') return false;
  }
  return false;
}

/**
 * Coerce JSON body fields (same string pitfalls as pgBool).
 */
export function bodyBool(val) {
  return pgBool(val);
}

/**
 * Sold-out flag for clients: **only** `is_sold_out`.
 * Do not OR with `is_available` — that column can drift and then toggling "Available" in admin
 * clears `is_sold_out` but the UI still looked "sold out". `is_available` is kept in sync on writes.
 */
export function soldOutFromRow(row) {
  if (!row) return false;
  return pgBool(row.is_sold_out);
}
