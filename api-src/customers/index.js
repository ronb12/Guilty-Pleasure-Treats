/**
 * Saved customers: list (admin) and create (admin).
 */
import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';

function combinedAddress(row) {
  const street = row.street?.trim();
  const line2 = row.address_line_2?.trim();
  const city = row.city?.trim();
  const state = row.state?.trim();
  const zip = row.postal_code?.trim();
  if (street || city || state || zip) {
    return [street, line2, city, state, zip].filter(Boolean).join('\n');
  }
  return row.address ?? null;
}

function rowToCustomer(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name ?? '',
    phone: row.phone ?? '',
    email: row.email ?? null,
    address: combinedAddress(row),
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
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  if (req.method === 'GET') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
    try {
      const rows = await sql`SELECT * FROM customers ORDER BY name ASC`;
      return res.status(200).json(rows.map(rowToCustomer));
    } catch (err) {
      console.error('customers GET', err);
      return res.status(500).json({ error: 'Failed to fetch customers' });
    }
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
    const body = req.body || {};
    const name = String(body.name ?? '').trim();
    const phone = String(body.phone ?? '').trim();
    if (!name) {
      return res.status(400).json({ error: 'name required' });
    }
    const email = body.email != null ? String(body.email).trim() || null : null;
    const notes = body.notes != null ? String(body.notes).trim() || null : null;
    const street = body.street != null ? String(body.street).trim() || null : null;
    const addressLine2 = body.addressLine2 != null ? String(body.addressLine2).trim() || null : (body.address_line_2 != null ? String(body.address_line_2).trim() || null : null);
    const city = body.city != null ? String(body.city).trim() || null : null;
    const state = body.state != null ? String(body.state).trim() || null : null;
    const postalCode = body.postalCode != null ? String(body.postalCode).trim() || null : (body.postal_code != null ? String(body.postal_code).trim() || null : null);
    const hasStructured = street || city || state || postalCode;
    const legacyAddress = body.address != null ? String(body.address).trim() || null : null;
    const address = hasStructured ? [street, addressLine2, city, state, postalCode].filter(Boolean).join('\n') : legacyAddress;
    try {
      const rows = await sql`
        INSERT INTO customers (name, phone, email, address, street, address_line_2, city, state, postal_code, notes)
        VALUES (${name}, ${phone}, ${email}, ${address}, ${street}, ${addressLine2}, ${city}, ${state}, ${postalCode}, ${notes})
        RETURNING *
      `;
      return res.status(201).json(rowToCustomer(rows[0]));
    } catch (err) {
      console.error('customers POST', err);
      return res.status(500).json({ error: 'Failed to create customer' });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
