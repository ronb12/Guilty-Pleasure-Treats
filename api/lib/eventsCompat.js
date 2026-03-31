/**
 * Production Neon may use a legacy `events` shape (NOT NULL `date`, `location`, …).
 * Never use awaitNeonRows for information_schema or INSERT — errors became [] and we cached
 * an empty column set, so every insert used the wrong shape and "saved" nothing.
 */
import { awaitNeonRows } from './db.js';

const COL_TTL_MS = 120_000;
let cachedCols = null;
let cachedAt = 0;

const DEFAULT_LEGACY_LOCATION = 'Guilty Pleasure Treats';

function invalidateColumnCache() {
  cachedCols = null;
  cachedAt = 0;
}

export async function getEventsColumnSet(sql) {
  const now = Date.now();
  if (cachedCols && cachedCols.size > 0 && now - cachedAt < COL_TTL_MS) {
    return cachedCols;
  }
  let rows;
  try {
    rows = await sql`
      SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'events'
    `;
  } catch (e) {
    console.error('[eventsCompat] getEventsColumnSet failed', e?.message ?? e);
    return new Set();
  }
  const set = new Set((rows || []).map((r) => String(r.column_name)));
  if (set.size > 0) {
    cachedCols = set;
    cachedAt = now;
  }
  return set;
}

function businessTZ() {
  return process.env.EVENTS_DISPLAY_TZ || 'America/New_York';
}

function legacyDateStr(d) {
  try {
    return d.toLocaleDateString('en-CA', { timeZone: businessTZ() });
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

function legacyTimeStr(d) {
  try {
    return d.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: businessTZ(),
    });
  } catch {
    return null;
  }
}

export function parseEventDate(v) {
  if (v == null || v === '') return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

async function insertLegacyShape(sql, p) {
  const { title, description, startAt, endAt, imageUrl, location } = p;
  const descText = description != null && String(description).trim() ? String(description).trim() : '';
  const locLegacy =
    location != null && String(location).trim() ? String(location).trim() : DEFAULT_LEGACY_LOCATION;
  const startD = parseEventDate(startAt);
  const endD = parseEventDate(endAt);
  const img = imageUrl != null && String(imageUrl).trim() ? String(imageUrl).trim() : null;
  const base = startD ?? new Date();
  const dateStr = legacyDateStr(base);
  const timeStr = startD ? legacyTimeStr(startD) : null;

  return sql`
    INSERT INTO events (
      title,
      date,
      time,
      location,
      description,
      display_order,
      start_at,
      end_at,
      image_url
    )
    VALUES (
      ${title},
      ${dateStr},
      ${timeStr},
      ${locLegacy},
      ${descText},
      0,
      ${startD},
      ${endD},
      ${img}
    )
    RETURNING id, title, description, start_at, end_at, image_url, location, created_at
  `;
}

async function insertModernShape(sql, p) {
  const { title, description, startAt, endAt, imageUrl, location } = p;
  const descText = description != null && String(description).trim() ? String(description).trim() : '';
  const locModern =
    location != null && String(location).trim() ? String(location).trim() : null;
  const startD = parseEventDate(startAt);
  const endD = parseEventDate(endAt);
  const img = imageUrl != null && String(imageUrl).trim() ? String(imageUrl).trim() : null;

  return sql`
    INSERT INTO events (title, description, start_at, end_at, image_url, location)
    VALUES (${title}, ${descText || null}, ${startD}, ${endD}, ${img}, ${locModern})
    RETURNING id, title, description, start_at, end_at, image_url, location, created_at
  `;
}

function shouldRetryAsLegacy(err) {
  const code = err?.code;
  const msg = String(err?.message || err || '');
  if (code === '23502' && /date|not null/i.test(msg)) return true;
  if (code === '42703') return true;
  return /column .* does not exist|null value in column "date"/i.test(msg);
}

/** @returns {Promise<Array>} RETURNING rows */
export async function insertEventRow(sql, p) {
  const cols = await getEventsColumnSet(sql);
  const hasLegacyDate = cols.has('date');

  if (hasLegacyDate) {
    return insertLegacyShape(sql, p);
  }

  try {
    return await insertModernShape(sql, p);
  } catch (e) {
    if (shouldRetryAsLegacy(e)) {
      console.warn('[eventsCompat] modern insert failed, retrying legacy shape', e?.code, e?.message ?? e);
      invalidateColumnCache();
      await getEventsColumnSet(sql);
      return insertLegacyShape(sql, p);
    }
    throw e;
  }
}

/** When `events.date` exists, keep legacy text columns in sync with `start_at` changes. */
export async function updateLegacyEventDateTime(sql, id, startAtRaw) {
  if (startAtRaw === undefined) return;
  const cols = await getEventsColumnSet(sql);
  if (!cols.has('date')) return;
  const sid = String(id ?? '').trim();
  if (!sid) return;
  const d = parseEventDate(startAtRaw);
  if (!d) {
    await awaitNeonRows(
      sql`UPDATE events SET date = ${legacyDateStr(new Date())}, time = NULL, updated_at = NOW() WHERE id = ${sid}`,
      'events_patch_legacy_date_fallback'
    );
    return;
  }
  await awaitNeonRows(
    sql`UPDATE events SET date = ${legacyDateStr(d)}, time = ${legacyTimeStr(d)}, updated_at = NOW() WHERE id = ${sid}`,
    'events_patch_legacy_date'
  );
}
