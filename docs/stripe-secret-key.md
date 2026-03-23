# Stripe secret key (server only)

The **secret** key (`sk_live_…` / `sk_test_…`) must **not** be committed to git.

Configure it in one of these ways:

1. **Vercel (recommended for production)**  
   Project → **Settings** → **Environment Variables** → add `STRIPE_SECRET_KEY` with your secret key. Redeploy if needed.

2. **Admin app**  
   **Business Settings** → paste the secret key and **Save**. It is stored in `business_settings` (`main.value_json.stripe_secret_key`) and never returned on GET.

The app’s **publishable** key may live in `AppConstants.stripePublishableKey` or in Business Settings from the API.

If a secret key was ever pasted in chat or committed by mistake, **rotate it** in [Stripe Dashboard → API keys](https://dashboard.stripe.com/apikeys).
