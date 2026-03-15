/**
 * Health check for Vercel / load balancers.
 * GET /api/health
 */
module.exports = (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.status(200).json({
    ok: true,
    service: 'Guilty Pleasure Treats API',
    timestamp: new Date().toISOString(),
  });
};
