/**
 * Build carrier tracking URLs (UPS / FedEx / USPS). Used by API responses and optional webhook updates.
 */

/** @param {unknown} input */
export function normalizeTrackingCarrier(input) {
  const s = String(input ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '');
  if (!s) return null;
  if (s === 'fedex' || s === 'fed-ex') return 'fedex';
  if (s === 'ups') return 'ups';
  if (s === 'usps' || s === 'unitedstatespostalservice') return 'usps';
  return null;
}

/**
 * @param {string | null} carrier - ups | fedex | usps (normalized)
 * @param {string | null | undefined} trackingNumber
 * @returns {string | null}
 */
export function carrierTrackingUrl(carrier, trackingNumber) {
  const num = String(trackingNumber ?? '').trim();
  if (!num) return null;
  const c = normalizeTrackingCarrier(carrier) || (carrier && String(carrier).trim().toLowerCase());
  if (c === 'ups') {
    return `https://www.ups.com/track?tracknum=${encodeURIComponent(num)}`;
  }
  if (c === 'fedex') {
    return `https://www.fedex.com/fedextrack/?trknbr=${encodeURIComponent(num)}`;
  }
  if (c === 'usps') {
    return `https://tools.usps.com/go/TrackConfirmAction?tLabels=${encodeURIComponent(num)}`;
  }
  return null;
}

/** @param {Record<string, unknown>} row - DB row with tracking_* columns */
export function parcelTrackingFieldsFromRow(row) {
  const rawCarrier = row.tracking_carrier != null ? String(row.tracking_carrier).trim().toLowerCase() : '';
  const carrier = rawCarrier || null;
  const number =
    row.tracking_number != null && String(row.tracking_number).trim() !== ''
      ? String(row.tracking_number).trim()
      : null;
  const url = carrierTrackingUrl(carrier, number);
  return {
    trackingCarrier: carrier,
    trackingNumber: number,
    trackingStatusDetail:
      row.tracking_status_detail != null && String(row.tracking_status_detail).trim() !== ''
        ? String(row.tracking_status_detail).trim()
        : null,
    trackingUpdatedAt: row.tracking_updated_at
      ? new Date(row.tracking_updated_at).toISOString()
      : null,
    parcelLabeledAt: row.parcel_labeled_at
      ? new Date(row.parcel_labeled_at).toISOString()
      : null,
    trackingUrl: url,
  };
}
