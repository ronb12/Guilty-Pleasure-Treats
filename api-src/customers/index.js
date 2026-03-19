/**
 * GET /api/customers — list saved customers (admin only).
 * POST /api/customers — create (admin only).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

function rowToCustomer(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? row.id,
    name: row.name ?? '',
    phone: row.phone ?? '',
    email: row.email ?? null,
    address: row.address ?? null,
    street: row.street ?? null,
    addressLine2: row.address_line_2 ?? null,
    city: row.city ?? null,
    state: row.state ?? null,
    postalCode: row.postal_code ?? null,
    notes: row.notes ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId || session.isAdmin !== true) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const rows = await sql`
        SELECT id, name, phone, email, address, street, address_line_2, city, state, postal_code, notes, created_at, updated_at
        FROM customers
        ORDER BY name ASC NULLS LAST
        LIMIT 2000
      `;
      return res.status(200).json((rows || []).map(rowToCustomer));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[customers] GET', err);
      return res.status(500).json({ error: 'Failed to fetch customers' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const phone = String(body.phone ?? '').trim();
    if (!name) return res.status(400).json({ error: 'name is required' });
    const email = body.email != null ? String(body.email).trim() || null : null;
    const street = body.street != null ? String(body.street).trim() || null : null;
    const addressLine2 = body.addressLine2 != null ? String(body.addressLine2).trim() || null : null;
    const city = body.city != null ? String(body.city).trim() || null : null;
    const state = body.state != null ? String(body.state).trim() || null : null;
    const postalCode = body.postalCode != null ? String(body.postalCode).trim() || null : null;
    const notes = body.notes != null ? String(body.notes).trim() || null : null;
    try {
      const [row] = await sql`
        INSERT INTO customers (name, phone, email, street, address_line_2, city, state, postal_code, notes)
        VALUES (${name}, ${phone}, ${email}, ${street}, ${addressLine2}, ${city}, ${state}, ${postalCode}, ${notes})
        RETURNING id, name, phone, email, address, street, address_line_2, city, state, postal_code, notes, created_at, updated_at
      `;
      return res.status(201).json(rowToCustomer(row));
    } catch (err) {
      console.error('[customers] POST', err);
      return res.status(500).json({ error: 'Failed to create customer' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
