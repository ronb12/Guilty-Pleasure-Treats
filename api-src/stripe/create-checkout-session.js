/**
 * Create a Stripe Checkout Session for an order. Admin only.
 * Returns { url } so the owner can copy/share the link with the buyer.
 * When the buyer pays, Stripe sends checkout.session.completed to the webhook and we mark the order paid.
 */
import Stripe from 'stripe';
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

const stripeSecret = process.env.STRIPE_SECRET_KEY;
const baseUrl = process.env.VERCEL_URL
  ? `https://${process.env.VERCEL_URL}`
  : process.env.BASE_URL || 'https://guilty-pleasure-treats.vercel.app';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session || !session.isAdmin) {
    return res.status(401).json({ error: 'Admin access required' });
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
  if (!orderId) {
    return res.status(400).json({ error: 'orderId required' });
  }

  let rows;
  try {
    rows = await sql`SELECT id, total, customer_name FROM orders WHERE id = ${orderId} LIMIT 1`;
  } catch (err) {
    console.error('stripe create-checkout-session order fetch', err);
    return res.status(500).json({ error: 'Failed to load order' });
  }
  const order = rows[0];
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }

  const amountCents = Math.round(Number(order.total) * 100);
  if (amountCents < 50) {
    return res.status(400).json({ error: 'Order total must be at least $0.50' });
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: '2024-11-20.acacia' });

  try {
    const checkoutSession = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: 'usd',
            unit_amount: amountCents,
            product_data: {
              name: `Order #${String(orderId).slice(0, 8)} – Guilty Pleasure Treats`,
              description: order.customer_name ? `for ${order.customer_name}` : undefined,
            },
          },
        },
      ],
      success_url: `${baseUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/payment-canceled`,
      metadata: {
        orderId: String(orderId),
      },
    });

    return res.status(200).json({
      url: checkoutSession.url,
      sessionId: checkoutSession.id,
    });
  } catch (err) {
    console.error('stripe create-checkout-session', err);
    return res.status(500).json({
      error: err.message || 'Failed to create payment link',
    });
  }
}
