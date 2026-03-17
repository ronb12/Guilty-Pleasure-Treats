/**
 * Stripe webhook: receives checkout.session.completed and marks the order paid.
 * Must use raw body for signature verification. Deploy as /api/stripe-webhook;
 * configure Stripe to send webhooks to https://your-domain/api/stripe/webhook
 * (rewritten to this handler).
 */
export const config = {
  api: { bodyParser: false },
};

import Stripe from 'stripe';
import { sql, hasDb } from './lib/db.js';

function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).end();
  }

  const stripeSecret = process.env.STRIPE_SECRET_KEY;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!stripeSecret || !webhookSecret) {
    console.error('Stripe webhook: STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET not set');
    return res.status(503).json({ error: 'Webhook not configured' });
  }

  const signature = req.headers['stripe-signature'];
  if (!signature) {
    return res.status(400).json({ error: 'Missing stripe-signature' });
  }

  let rawBody;
  try {
    rawBody = await getRawBody(req);
  } catch (err) {
    console.error('Stripe webhook: failed to read body', err);
    return res.status(400).json({ error: 'Invalid body' });
  }

  let event;
  try {
    event = Stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (err) {
    console.error('Stripe webhook: signature verification failed', err.message);
    return res.status(400).json({ error: 'Invalid signature' });
  }

  if (!hasDb() || !sql) {
    console.error('Stripe webhook: database not configured');
    return res.status(503).json({ error: 'Database not configured' });
  }

  const now = new Date();

  // Payment Sheet (in-app): payment_intent.succeeded
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data?.object;
    const orderId = paymentIntent?.metadata?.orderId;
    const paymentIntentId = paymentIntent?.id ?? null;
    if (!orderId) {
      return res.status(200).json({ received: true });
    }
    try {
      await sql`
        UPDATE orders
        SET stripe_payment_intent_id = ${paymentIntentId},
            status = 'Confirmed',
            updated_at = ${now}
        WHERE id = ${orderId}
      `;
    } catch (err) {
      console.error('Stripe webhook: failed to update order (payment_intent)', orderId, err);
      return res.status(500).json({ error: 'Failed to update order' });
    }
    return res.status(200).json({ received: true });
  }

  // Checkout Session (payment link): checkout.session.completed
  if (event.type !== 'checkout.session.completed') {
    return res.status(200).json({ received: true });
  }

  const session = event.data?.object;
  const orderId = session?.metadata?.orderId;
  const paymentIntentId = session?.payment_intent ?? null;
  if (!orderId) {
    console.error('Stripe webhook: checkout.session.completed missing metadata.orderId');
    return res.status(200).json({ received: true });
  }

  try {
    await sql`
      UPDATE orders
      SET stripe_payment_intent_id = ${paymentIntentId},
          status = 'Confirmed',
          updated_at = ${now}
      WHERE id = ${orderId}
    `;
  } catch (err) {
    console.error('Stripe webhook: failed to update order', orderId, err);
    return res.status(500).json({ error: 'Failed to update order' });
  }

  return res.status(200).json({ received: true });
}
