/**
 * GET /api/product-categories - list categories (displayOrder, name).
 * POST /api/product-categories - add category (auth). Stub returns 501 until implemented.
 */
export default async function handler(req, res) {
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() === 'GET') {
    res.status(200).json([]);
    return;
  }
  res.status(501).json({ error: 'Not implemented' });
}
