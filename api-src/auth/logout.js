import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, deleteSession } from '../../api/lib/auth.js';

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
  if (token) {
    await deleteSession(token);
  }

  res.status(200).json({ ok: true });
}
