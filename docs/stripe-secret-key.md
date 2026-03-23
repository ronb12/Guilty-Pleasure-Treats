# Stripe keys (server)

The **secret** key (`sk_live_…` / `sk_test_…`) must **not** be committed to git.

### Secret (`STRIPE_SECRET_KEY`)

1. **Vercel (recommended for production)**  
   Project → **Settings** → **Environment Variables** → add `STRIPE_SECRET_KEY`. Redeploy after changes.

2. **Admin app**  
   **Business Settings** → paste the secret key and **Save**. Stored in `business_settings` (`main.value_json.stripe_secret_key`) and never returned on GET.

### Publishable key (`pk_live_…` / `pk_test_…`)

- **Admin:** **Business Settings** → **Publishable key** → paste → **Save** (stored in DB; returned on `GET /api/settings/business`).
- **Vercel (optional):** `STRIPE_PUBLISHABLE_KEY` — used when the DB value is empty so the API still returns a publishable key without rebuilding the iOS app.

The iOS app can also use a fallback in `AppConstants.stripePublishableKey`.

If a secret key was ever pasted in chat or committed by mistake, **rotate it** in [Stripe Dashboard → API keys](https://dashboard.stripe.com/apikeys).
