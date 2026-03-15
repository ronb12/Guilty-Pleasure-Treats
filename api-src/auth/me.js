import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  if (!token) {
    return res.status(401).json({ error: 'Not signed in' });
  }

  const session = await getSession(token);
  if (!session) {
    return res.status(401).json({ error: 'Session expired or invalid' });
  }

  res.status(200).json({
    uid: session.userId,
    email: session.email,
    displayName: session.displayName,
    isAdmin: session.isAdmin,
    points: session.points,
  });
}
