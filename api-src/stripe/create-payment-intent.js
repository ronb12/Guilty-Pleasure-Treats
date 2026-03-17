/**
 * Create a Stripe PaymentIntent for in-app Payment Sheet.
 * Called by the app after creating an order. Returns client_secret for StripePaymentSheet.
 * When the customer pays, Stripe sends payment_intent.succeeded to the webhook and we mark the order paid.
 */
import Stripe from 'stripe';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';

const stripeSecret = process.env.STRIPE_SECRET_KEY;

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!stripeSecret || !stripeSecret.startsWith('sk_')) {
    return res.status(503).json({
      error: 'Stripe is not configured. Set STRIPE_SECRET_KEY in Vercel Environment Variables.',
    });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const orderId = req.body?.orderId;
  const amountCents = req.body?.amount != null ? Math.round(Number(req.body.amount)) : null;
  if (!orderId || amountCents == null || amountCents < 50) {
    return res.status(400).json({ error: 'amount (cents) and orderId required; amount must be at least 50.' });
  }

  let rows;
  try {
    rows = await sql`SELECT id, total FROM orders WHERE id = ${orderId} LIMIT 1`;
  } catch (err) {
    console.error('stripe create-payment-intent order fetch', err);
    return res.status(500).json({ error: 'Failed to load order' });
  }
  const order = rows[0];
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }

  const expectedCents = Math.round(Number(order.total) * 100);
  if (Math.abs(amountCents - expectedCents) > 1) {
    return res.status(400).json({ error: 'Amount does not match order total.' });
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: '2024-11-20.acacia' });

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: 'usd',
      automatic_payment_methods: { enabled: true },
      metadata: { orderId: String(orderId) },
    });

    return res.status(200).json({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (err) {
    console.error('stripe create-payment-intent', err);
    return res.status(500).json({
      error: err.message || 'Failed to create payment intent',
    });
  }
}
