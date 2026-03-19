/**
 * GET /api/reviews - list reviews. Stub returns empty array until implemented.
 */
export default async function handler(req, res) {
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() === 'GET') {
    res.status(200).json([]);
    return;
  }
  res.status(501).json({ error: 'Not implemented' });
}
