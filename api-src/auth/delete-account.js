/**
 * POST /api/auth/delete-account
 * Deletes the signed-in user's account and associated data (App Store requirement 5.1.1(v)).
 * Requires Bearer token. After deletion the session is invalid; client should sign out locally.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session) {
    return res.status(401).json({ error: 'Not signed in' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const userId = session.userId;
  const userIdStr = userId != null ? String(userId) : null;
  if (!userIdStr) {
    return res.status(400).json({ error: 'Invalid session' });
  }

  try {
    // Anonymize data that references user by id (no FK): orders, custom_cake_orders, ai_cake_designs, contact_messages
    await sql`UPDATE orders SET user_id = NULL WHERE user_id = ${userIdStr}`;
    await sql`UPDATE custom_cake_orders SET user_id = NULL WHERE user_id = ${userIdStr}`;
    await sql`UPDATE ai_cake_designs SET user_id = NULL WHERE user_id = ${userIdStr}`;
    await sql`UPDATE contact_messages SET user_id = NULL WHERE user_id = ${userIdStr}`;
    // Remove reset tokens; sessions and push_tokens will be removed by CASCADE when we delete the user
    await sql`DELETE FROM password_reset_tokens WHERE user_id = ${userId}`;
    await sql`DELETE FROM users WHERE id = ${userId}`;
    return res.status(200).json({ message: 'Account deleted.' });
  } catch (err) {
    console.error('delete-account', err);
    return res.status(500).json({ error: 'Could not delete account. Please try again.' });
  }
}
