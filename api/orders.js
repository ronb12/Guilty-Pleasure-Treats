/**
 * Orders endpoint (placeholder). Replace with DB and auth later.
 * GET /api/orders - list (stub)
 * POST /api/orders - create (stub)
 */
module.exports = (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method === 'GET') {
    res.status(200).json({ orders: [], message: 'Connect a database to store orders.' });
    return;
  }
  if (req.method === 'POST') {
    const body = req.body || {};
    res.status(201).json({
      id: `ord_${Date.now()}`,
      message: 'Order received (stub). Add Vercel Postgres or another DB to persist.',
      items: body.items || [],
    });
    return;
  }
  res.status(405).json({ error: 'Method not allowed' });
};
