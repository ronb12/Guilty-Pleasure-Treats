/**
 * Resolve Stripe secret key: Vercel env first, then business_settings (main.stripe_secret_key).
 * @param {import('@neondatabase/serverless').NeonQueryFunction|null} sql
 * @returns {Promise<string|null>}
 */
export async function getStripeSecretKey(sql) {
  const env = typeof process.env.STRIPE_SECRET_KEY === 'string' ? process.env.STRIPE_SECRET_KEY.trim() : '';
  if (env) return env;
  if (!sql) return null;
  try {
    const rows = await sql`SELECT value_json FROM business_settings WHERE key = 'main' LIMIT 1`;
    const row = rows?.[0];
    const v = row?.value_json;
    const k = v?.stripe_secret_key;
    if (typeof k === 'string' && k.trim().length > 0) return k.trim();
  } catch (e) {
    console.error('[stripeSecret] read failed', e?.message ?? e);
  }
  return null;
}
