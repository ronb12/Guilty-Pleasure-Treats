# Stripe checkout (in-app)

## Admin (Business Settings)

1. Open the app → Admin → **Settings** (Business Settings).
2. Scroll to **Stripe checkout**.
3. Add your keys from Stripe (see below) and tap **Save**.

- **Publishable key** (`pk_live_…` or `pk_test_…`) is stored in the database and returned to the app so customers can open the Payment Sheet.
- **Secret key** (`sk_live_…` or `sk_test_…`) is stored in the database **only on the server** and is **never** sent back to the app. It is used to create PaymentIntents.

Alternatively, you can set **`STRIPE_SECRET_KEY`** in the Vercel project → Settings → Environment Variables (Production). The API checks the environment variable **first**, then the database.

## Where to find Stripe keys

1. Go to [https://dashboard.stripe.com](https://dashboard.stripe.com) and sign in.
2. Use the **Test mode** toggle (top right) for test keys, or turn it **off** for **live** keys.
3. Open **Developers** → **API keys**.
4. Copy **Publishable key** into the app’s Business Settings.
5. Under **Secret key**, click **Reveal** and copy the **Secret key** into Business Settings (or paste only into Vercel as `STRIPE_SECRET_KEY`).

## Customer flow

When both a publishable key is available (from settings or `AppConstants.stripePublishableKey`) **and** the server can create PaymentIntents (secret in env or DB), checkout shows **Pay with card** and opens Stripe’s Payment Sheet after the order is created.

## Security notes

- Prefer **Vercel env** for the secret key in production; restrict who can open Admin Settings.
- Never commit `sk_` keys to git.
- Rotate keys in Stripe if they are exposed.
