/**
 * Root API info.
 * GET /api
 */
module.exports = (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.status(200).json({
    name: 'Guilty Pleasure Treats',
    version: '1.0',
    endpoints: {
      health: '/api/health',
      products: '/api/products',
      orders: '/api/orders',
    },
  });
};
