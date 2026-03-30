/**
 * PATCH /api/customers/:id — update saved customer (admin only).
 * DELETE /api/customers/:id — delete (admin only).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

async function ensureCustomersOptionalColumns(sql) {
  try {
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS food_allergies TEXT`;
  } catch (e) {
    if (e?.code !== '42P01') console.warn('[customers/id] food_allergies column', e?.message ?? e);
  }
}

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
    foodAllergies:
      row.food_allergies != null && String(row.food_allergies).trim() !== ''
        ? String(row.food_allergies).trim()
        : null,
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

  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'id required' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId || session.isAdmin !== true) {
    return res.status(403).json({ error: 'Admin required' });
  }
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  await ensureCustomersOptionalColumns(sql);

  const method = (req.method || '').toUpperCase();

  if (method === 'DELETE') {
    try {
      const result = await sql`DELETE FROM customers WHERE id = ${id}::uuid RETURNING id`;
      if (!result?.length) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json({ ok: true });
    } catch (err) {
      console.error('[customers/id] DELETE', err);
      return res.status(500).json({ error: 'Delete failed' });
    }
  }

  if (method === 'PATCH') {
    try {
      const [existing] = await sql`
        SELECT id, name, phone, email, address, street, address_line_2, city, state, postal_code, notes, food_allergies
        FROM customers WHERE id = ${id}::uuid LIMIT 1
      `;
      if (!existing) return res.status(404).json({ error: 'Not found' });
      const body = req.body || {};
      const name = body.name !== undefined ? String(body.name).trim() : existing.name;
      const phone = body.phone !== undefined ? String(body.phone).trim() : existing.phone;
      const email = body.email !== undefined ? (body.email == null ? null : String(body.email).trim() || null) : existing.email;
      const street = body.street !== undefined ? (body.street == null ? null : String(body.street).trim() || null) : existing.street;
      const addressLine2 =
        body.addressLine2 !== undefined
          ? body.addressLine2 == null
            ? null
            : String(body.addressLine2).trim() || null
          : existing.address_line_2;
      const city = body.city !== undefined ? (body.city == null ? null : String(body.city).trim() || null) : existing.city;
      const state = body.state !== undefined ? (body.state == null ? null : String(body.state).trim() || null) : existing.state;
      const postalCode =
        body.postalCode !== undefined
          ? body.postalCode == null
            ? null
            : String(body.postalCode).trim() || null
          : existing.postal_code;
      const notes = body.notes !== undefined ? (body.notes == null ? null : String(body.notes).trim() || null) : existing.notes;
      const foodAllergies =
        body.foodAllergies !== undefined || body.food_allergies !== undefined
          ? (() => {
              const raw = body.foodAllergies !== undefined ? body.foodAllergies : body.food_allergies;
              if (raw == null) return null;
              const t = String(raw).trim();
              return t !== '' ? t : null;
            })()
          : existing.food_allergies;

      const [row] = await sql`
        UPDATE customers
        SET name = ${name}, phone = ${phone}, email = ${email}, street = ${street}, address_line_2 = ${addressLine2},
            city = ${city}, state = ${state}, postal_code = ${postalCode}, notes = ${notes},
            food_allergies = ${foodAllergies}, updated_at = NOW()
        WHERE id = ${id}::uuid
        RETURNING id, name, phone, email, address, street, address_line_2, city, state, postal_code, notes, food_allergies, created_at, updated_at
      `;
      return res.status(200).json(rowToCustomer(row));
    } catch (err) {
      console.error('[customers/id] PATCH', err);
      return res.status(500).json({ error: 'Update failed' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
