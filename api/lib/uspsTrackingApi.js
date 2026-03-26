/**
 * USPS Tracking 3.0 (summary) via OAuth 2.0 client credentials.
 * Free USPS developer app: https://developers.usps.com/getting-started
 * Production base: https://apis.usps.com — TEM: https://apis-tem.usps.com
 */

/** @param {unknown} json */
export function summaryTextFromUspsTrackingPayload(json) {
  if (!json || typeof json !== 'object') return '';
  const tr = /** @type {Record<string, unknown>} */ (json).TrackResults;
  const ti = tr && typeof tr === 'object' ? /** @type {Record<string, unknown>} */ (tr).TrackInfo : null;
  const trackSummary = ti && typeof ti === 'object' ? /** @type {Record<string, unknown>} */ (ti).TrackSummary : null;
  if (trackSummary != null && String(trackSummary).trim() !== '') return String(trackSummary).trim();

  const j = /** @type {Record<string, unknown>} */ (json);
  if (j.statusSummary != null && String(j.statusSummary).trim() !== '') return String(j.statusSummary).trim();
  if (j.status != null && String(j.status).trim() !== '') return String(j.status).trim();
  const events = j.trackingEvents;
  const ev0 = Array.isArray(events) && events[0] && typeof events[0] === 'object' ? events[0] : null;
  const et = ev0 ? /** @type {Record<string, unknown>} */ (ev0).eventType : null;
  if (et != null && String(et).trim() !== '') return String(et).trim();
  return '';
}

/**
 * @param {string} baseUrl e.g. https://apis.usps.com
 * @param {string} clientId
 * @param {string} clientSecret
 */
export async function fetchUspsOAuthToken(baseUrl, clientId, clientSecret) {
  const base = baseUrl.replace(/\/$/, '');
  const url = `${base}/oauth2/v3/token`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data?.error_description || data?.error || data?.message || `USPS OAuth HTTP ${res.status}`;
    throw new Error(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }
  const access = data.access_token;
  if (!access) throw new Error('USPS OAuth: missing access_token');
  const expiresIn = Number(data.expires_in);
  return {
    accessToken: String(access),
    expiresInSec: Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 3600,
  };
}

let _token = null;
let _tokenExpiresAtMs = 0;

/**
 * @param {{ clientId: string, clientSecret: string, baseUrl: string, trackingNumber: string }} opts
 * @returns {Promise<string>} human-readable latest summary line
 */
export async function fetchUspsTrackingSummaryText(opts) {
  const base = (opts.baseUrl || 'https://apis.usps.com').replace(/\/$/, '');
  const num = String(opts.trackingNumber || '').trim();
  if (!num) return '';

  const now = Date.now();
  const refreshToken = async () => {
    const tok = await fetchUspsOAuthToken(base, opts.clientId, opts.clientSecret);
    _token = tok.accessToken;
    _tokenExpiresAtMs = now + Math.max(120_000, (tok.expiresInSec - 90) * 1000);
  };

  if (!_token || now >= _tokenExpiresAtMs) {
    await refreshToken();
  }

  const tryOnce = async () => {
    const trackUrl = `${base}/tracking/v3/tracking/${encodeURIComponent(num)}?expand=summary`;
    const res = await fetch(trackUrl, {
      headers: { Authorization: `Bearer ${_token}` },
    });
    const json = await res.json().catch(() => ({}));
    return { res, json };
  };

  let { res, json } = await tryOnce();
  if (res.status === 401) {
    _token = null;
    _tokenExpiresAtMs = 0;
    await refreshToken();
    ({ res, json } = await tryOnce());
  }

  if (!res.ok) {
    const msg = json?.message || json?.error || json?.errorMessage || `USPS tracking HTTP ${res.status}`;
    throw new Error(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }

  return summaryTextFromUspsTrackingPayload(json);
}
