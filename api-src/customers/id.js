/**
 * Single saved customer: PATCH (admin), DELETE (admin).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

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
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'id required' });
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session || !session.isAdmin) {
    return res.status(401).json({ error: 'Admin required' });
  }

  const rows = await sql`SELECT * FROM customers WHERE id = ${id} LIMIT 1`;
  const existing = rows[0];
  if (!existing) return res.status(404).json({ error: 'Customer not found' });

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const name = body.name !== undefined ? String(body.name).trim() : existing.name;
    const phone = body.phone !== undefined ? String(body.phone).trim() : existing.phone;
    const email = body.email !== undefined ? (String(body.email).trim() || null) : existing.email;
    const notes = body.notes !== undefined ? (String(body.notes).trim() || null) : existing.notes;
    const street = body.street !== undefined ? (String(body.street).trim() || null) : existing.street;
    const addressLine2 = body.addressLine2 !== undefined ? (String(body.addressLine2).trim() || null) : existing.address_line_2;
    const city = body.city !== undefined ? (String(body.city).trim() || null) : existing.city;
    const state = body.state !== undefined ? (String(body.state).trim() || null) : existing.state;
    const postalCode = body.postalCode !== undefined ? (String(body.postalCode).trim() || null) : existing.postal_code;
    const hasStructured = street || city || state || postalCode;
    const legacyAddress = body.address !== undefined ? (String(body.address).trim() || null) : existing.address;
    const address = hasStructured ? [street, addressLine2, city, state, postalCode].filter(Boolean).join('\n') : legacyAddress;
    if (!name) return res.status(400).json({ error: 'name required' });
    try {
      await sql`
        UPDATE customers SET name = ${name}, phone = ${phone}, email = ${email}, address = ${address}, street = ${street}, address_line_2 = ${addressLine2}, city = ${city}, state = ${state}, postal_code = ${postalCode}, notes = ${notes}, updated_at = NOW()
        WHERE id = ${id}
      `;
      const updated = await sql`SELECT * FROM customers WHERE id = ${id} LIMIT 1`;
      return res.status(200).json(rowToCustomer(updated[0]));
    } catch (err) {
      console.error('customers PATCH', err);
      return res.status(500).json({ error: 'Failed to update customer' });
    }
  }

  if (req.method === 'DELETE') {
    await sql`DELETE FROM customers WHERE id = ${id}`;
    return res.status(204).end();
  }

  res.status(405).json({ error: 'Method not allowed' });
}
