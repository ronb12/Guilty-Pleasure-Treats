/**
 * POST /api/stripe/create-payment-intent
 * Body: { amount: number (cents), currency?: string, orderId: string (uuid) }
 * Returns: { clientSecret: string }
 * Auth: none (order total is verified server-side).
 */
import Stripe from 'stripe';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getStripeSecretKey } from '../../api/lib/stripeSecret.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Service unavailable' });
  }

  const secret = await getStripeSecretKey(sql);
  if (!secret) {
    return res.status(503).json({
      error:
        'Stripe is not configured. Add your Secret key in Admin → Business Settings (Stripe), or set STRIPE_SECRET_KEY in Vercel.',
    });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const amount = Number(body.amount);
  const currency = String(body.currency || 'usd').toLowerCase();
  const orderId = String(body.orderId || '').trim();

  if (!orderId || !Number.isFinite(amount) || amount < 50 || amount > 99_999_999) {
    return res.status(400).json({ error: 'Invalid amount or orderId' });
  }

  try {
    const rows = await sql`
      SELECT id, total, status, stripe_payment_intent_id
      FROM orders WHERE id = ${orderId}::uuid LIMIT 1
    `;
    const order = rows?.[0];
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    const st = String(order.status ?? '').trim().toLowerCase();
    if (st === 'cancelled' || st === 'completed') {
      return res.status(400).json({ error: 'This order cannot be paid online.' });
    }

    const expectedCents = Math.round(Number(order.total) * 100);
    if (!Number.isFinite(expectedCents) || Math.abs(amount - expectedCents) > 2) {
      return res.status(400).json({ error: 'Amount does not match order total' });
    }

    const stripe = new Stripe(secret, { apiVersion: '2023-10-16' });
    // Card only (debit/credit + Apple Pay on device) — no PayPal / BNPL / wallets that require other accounts.
    const intent = await stripe.paymentIntents.create({
      amount,
      currency,
      metadata: { order_id: orderId },
      payment_method_types: ['card'],
    });

    await sql`
      UPDATE orders SET stripe_payment_intent_id = ${intent.id}, updated_at = NOW()
      WHERE id = ${orderId}::uuid
    `;

    return res.status(200).json({ clientSecret: intent.client_secret });
  } catch (e) {
    if (e?.code === '22P02') {
      return res.status(400).json({ error: 'Invalid order id' });
    }
    console.error('[stripe/create-payment-intent]', e?.message ?? e);
    return res.status(500).json({ error: e.message || 'Payment intent failed' });
  }
}
