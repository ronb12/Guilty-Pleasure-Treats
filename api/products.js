/**
 * Products endpoint (placeholder). Replace with DB (e.g. Vercel Postgres) later.
 * GET /api/products
 */
const placeholderProducts = [
  { id: '1', name: 'Classic Cupcake', category: 'Cupcakes', price: 3.5, available: true },
  { id: '2', name: 'Chocolate Chip Cookie', category: 'Cookies', price: 2.5, available: true },
];

module.exports = (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  res.status(200).json(placeholderProducts);
};
