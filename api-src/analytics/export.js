/**
 * GET /api/analytics/export — CSV export of orders for accounting (admin).
 * Query: from=YYYY-MM-DD&to=YYYY-MM-DD (optional; default last 30 days)
 */
const { withCors } = require('../../api/lib/cors');
const { getAuth } = require('../../api/lib/auth');
const { sql } = require('../../api/lib/db');

function escapeCsv(s) {
  if (s == null) return '';
  const t = String(s);
  if (/[",\n\r]/.test(t)) return '"' + t.replace(/"/g, '""') + '"';
  return t;
}

async function handler(req, res) {
  if (req.method === 'OPTIONS') return withCors(req, res, () => res.status(204).end());
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const auth = await getAuth(req);
  if (!auth?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (auth.isAdmin !== true) return res.status(403).json({ error: 'Admin only' });

  const from = req.query?.from;
  const to = req.query?.to;
  const fromDate = from ? new Date(from) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const toDate = to ? new Date(to) : new Date();

  try {
    const rows = await sql`
      SELECT id, customer_name, total, status, tip_cents, tax_cents, pickup_time, created_at, updated_at
      FROM orders
      WHERE created_at >= ${fromDate} AND created_at <= ${toDate}
      ORDER BY created_at ASC
    `;
    const headers = ['id', 'customer_name', 'total', 'status', 'tip_cents', 'tax_cents', 'pickup_time', 'created_at', 'updated_at'];
    const csv = [headers.join(',')].concat(
      (rows || []).map((r) => headers.map((h) => escapeCsv(r[h])).join(','))
    ).join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=orders-${fromDate.toISOString().slice(0, 10)}-${toDate.toISOString().slice(0, 10)}.csv`);
    return res.status(200).send(csv);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Export failed' });
  }
}

module.exports = handler;
