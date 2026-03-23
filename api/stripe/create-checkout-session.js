/**
 * POST /api/stripe/create-checkout-session
 * Body: { orderId: string (uuid) }
 * Returns: { url: string } — Stripe-hosted Checkout URL (admin only).
 */
import Stripe from 'stripe';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getStripeSecretKey } from '../../api/lib/stripeSecret.js';
import { getAuth } from '../../api/lib/auth.js';

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

  const auth = await getAuth(req);
  if (!auth?.userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  if (auth.isAdmin !== true) {
    return res.status(403).json({ error: 'Admin only' });
  }

  const secret = await getStripeSecretKey(sql);
  if (!secret) {
    return res.status(503).json({
      error:
        'Stripe is not configured. Add your Secret key in Admin → Business Settings (Stripe), or set STRIPE_SECRET_KEY in Vercel.',
    });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const orderId = String(body.orderId || '').trim();
  if (!orderId) {
    return res.status(400).json({ error: 'orderId required' });
  }

  const proto = (req.headers['x-forwarded-proto'] || 'https').split(',')[0].trim();
  const host = (req.headers['x-forwarded-host'] || req.headers.host || '').split(',')[0].trim();
  const baseUrl =
    host && !host.includes('localhost') ? `${proto}://${host}` : 'https://guilty-pleasure-treats.vercel.app';

  try {
    const rows = await sql`
      SELECT id, total, status, customer_name
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
    if (!Number.isFinite(expectedCents) || expectedCents < 50) {
      return res.status(400).json({ error: 'Invalid order total' });
    }

    const stripe = new Stripe(secret, { apiVersion: '2023-10-16' });
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: 'Guilty Pleasure Treats order',
              description: order.customer_name
                ? `Order for ${String(order.customer_name).slice(0, 80)}`
                : `Order ${orderId}`,
            },
            unit_amount: expectedCents,
          },
          quantity: 1,
        },
      ],
      payment_intent_data: {
        metadata: { order_id: orderId },
      },
      metadata: { order_id: orderId },
      success_url: `${baseUrl}/?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/?checkout=cancelled`,
    });

    const piId =
      typeof session.payment_intent === 'string'
        ? session.payment_intent
        : session.payment_intent?.id ?? null;
    if (piId) {
      await sql`
        UPDATE orders SET stripe_payment_intent_id = ${piId}, updated_at = NOW()
        WHERE id = ${orderId}::uuid
      `;
    }

    return res.status(200).json({ url: session.url });
  } catch (e) {
    if (e?.code === '22P02') {
      return res.status(400).json({ error: 'Invalid order id' });
    }
    console.error('[stripe/create-checkout-session]', e?.message ?? e);
    return res.status(500).json({ error: e.message || 'Checkout session failed' });
  }
}
