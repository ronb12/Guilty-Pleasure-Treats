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
 * Sold out for API / app: true if `is_sold_out` OR not `is_available` (when column exists).
 * Fixes Neon rows where inventory exists but `is_available` was false without toggling sold-out.
 */
export function soldOutFromRow(row) {
  if (!row) return false;
  if (pgBool(row.is_sold_out)) return true;
  if (row.is_available === undefined || row.is_available === null) return false;
  return !pgBool(row.is_available);
}
