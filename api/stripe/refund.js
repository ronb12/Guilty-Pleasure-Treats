/**
 * POST /api/stripe/refund — create full or partial refund (admin).
 * Body: { orderId: string (uuid), amountCents?: number (optional; omit for full refund), reason?: string }
 */
const { withCors } = require('../../api/lib/cors');
const { getAuth } = require('../../api/lib/auth');
const { sql } = require('../../api/lib/db');
const Stripe = require('stripe');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', { apiVersion: '2023-10-16' });

async function handler(req, res) {
  if (req.method === 'OPTIONS') return withCors(req, res, () => res.status(204).end());
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const auth = getAuth(req);
  if (!auth?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (auth.isAdmin !== true) return res.status(403).json({ error: 'Admin only' });

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
  } catch {
    return res.status(400).json({ error: 'Invalid JSON' });
  }
  const { orderId, amountCents, reason } = body;
  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  if (!process.env.STRIPE_SECRET_KEY) return res.status(503).json({ error: 'Stripe not configured' });

  try {
    const [order] = await sql`SELECT id, total, stripe_payment_intent_id, status FROM orders WHERE id = ${orderId}`;
    if (!order) return res.status(404).json({ error: 'Order not found' });
    const paymentIntentId = order.stripe_payment_intent_id;
    if (!paymentIntentId) return res.status(400).json({ error: 'Order has no payment to refund' });

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    const chargeId = paymentIntent.latest_charge;
    if (!chargeId) return res.status(400).json({ error: 'No charge found' });

    const refundAmount = amountCents != null ? Math.min(Math.max(0, amountCents), Number(order.total) * 100) : undefined;
    const refundParams = { charge: chargeId, reason: reason || 'requested_by_customer' };
    if (refundAmount != null && refundAmount > 0) refundParams.amount = refundAmount;

    const refund = await stripe.refunds.create(refundParams);
    const isFullRefund = refundAmount == null || refundAmount >= Math.round(Number(order.total) * 100);
    if (isFullRefund) await sql`UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = ${orderId}`;
    return res.status(200).json({ refundId: refund.id, status: refund.status });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'Refund failed' });
  }
}

module.exports = handler;
