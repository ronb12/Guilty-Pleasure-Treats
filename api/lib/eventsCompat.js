/**
 * Production Neon may use a legacy `events` shape (NOT NULL `date`, `location`, `description`)
 * alongside `start_at` / `image_url`. Inserts that omit `date` fail silently via awaitNeonRows → empty result.
 */
import { awaitNeonRows } from './db.js';

const COL_TTL_MS = 120_000;
let cachedCols = null;
let cachedAt = 0;

const DEFAULT_LEGACY_LOCATION = 'Guilty Pleasure Treats';

export async function getEventsColumnSet(sql) {
  const now = Date.now();
  if (cachedCols && now - cachedAt < COL_TTL_MS) return cachedCols;
  const rows = await awaitNeonRows(
    sql`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'events'
  `,
    'events_info_columns'
  );
  cachedCols = new Set(rows.map((r) => String(r.column_name)));
  cachedAt = now;
  return cachedCols;
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

/** @returns {Promise<Array>} RETURNING rows or [] */
export async function insertEventRow(sql, p) {
  const { title, description, startAt, endAt, imageUrl, location } = p;
  const descText = description != null && String(description).trim() ? String(description).trim() : '';
  const locModern =
    location != null && String(location).trim() ? String(location).trim() : null;
  const locLegacy =
    location != null && String(location).trim() ? String(location).trim() : DEFAULT_LEGACY_LOCATION;
  const startD = parseEventDate(startAt);
  const endD = parseEventDate(endAt);
  const img = imageUrl != null && String(imageUrl).trim() ? String(imageUrl).trim() : null;

  const cols = await getEventsColumnSet(sql);
  const hasLegacyDate = cols.has('date');

  if (hasLegacyDate) {
    const base = startD ?? new Date();
    const dateStr = legacyDateStr(base);
    const timeStr = startD ? legacyTimeStr(startD) : null;

    return awaitNeonRows(
      sql`
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
    `,
      'events_POST_insert_legacy'
    );
  }

  return awaitNeonRows(
    sql`
    INSERT INTO events (title, description, start_at, end_at, image_url, location)
    VALUES (${title}, ${descText || null}, ${startD}, ${endD}, ${img}, ${locModern})
    RETURNING id, title, description, start_at, end_at, image_url, location, created_at
  `,
    'events_POST_insert_modern'
  );
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
