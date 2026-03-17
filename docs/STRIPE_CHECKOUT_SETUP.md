# Complete Stripe Checkout Setup (Client Guide)

This guide is for the **business owner (client)** so they can accept card payments in the app. The flow is: customer places order → **Stripe Payment Sheet** appears in the app → customer pays with card (or Apple Pay) → order is marked paid and confirmed.

---

## 1. Stripe Account

1. Go to [stripe.com](https://stripe.com) and sign up or log in.
2. Complete business verification when prompted (needed for live payments).
3. **Test mode:** Use **Developers → Viewing test data** (toggle ON) while testing. Use **live** keys and turn the toggle OFF for real payments.

---

## 2. Get Your Stripe Keys

1. In Stripe Dashboard go to **Developers → API keys**.
2. You’ll see:
   - **Publishable key** (starts with `pk_test_` or `pk_live_`).  
     → Used by the **app** (safe to ship in the app).
   - **Secret key** (starts with `sk_test_` or `sk_live_`).  
     → Used **only** by the **backend** (Vercel). Never put this in the app or in client-visible code.

---

## 3. Vercel (Backend) Setup

The backend creates payment intents and receives webhooks. The client (or you) needs access to the Vercel project.

1. Open the project on [vercel.com](https://vercel.com) → **Settings → Environment Variables**.
2. Add these for **Production** (and **Preview** if you test on staging):

   | Name                     | Value              | Notes                          |
   |--------------------------|--------------------|--------------------------------|
   | `STRIPE_SECRET_KEY`      | `sk_test_...` or `sk_live_...` | From Stripe API keys (Secret key). |
   | `STRIPE_WEBHOOK_SECRET`  | `whsec_...`        | From step 4 below.             |

3. **Save** and **redeploy** the project so the new variables are used.

---

## 4. Stripe Webhook (So Orders Are Marked Paid)

When a customer pays, Stripe notifies your backend; the backend then marks the order as paid and confirmed.

1. In Stripe Dashboard go to **Developers → Webhooks**.
2. Click **Add endpoint**.
3. **Endpoint URL:**  
   `https://guilty-pleasure-treats.vercel.app/api/stripe-webhook`  
   (Replace with the real Vercel URL if different.)
4. Click **Select events** and add:
   - **payment_intent.succeeded** (in-app Payment Sheet)
   - **checkout.session.completed** (if you still use “payment link” from Admin)
5. Click **Add endpoint**.
6. Open the new endpoint and click **Reveal** under **Signing secret**.
7. Copy the value (starts with `whsec_...`).
8. In Vercel, add it as **STRIPE_WEBHOOK_SECRET** (see step 3) and redeploy.

---

## 5. App (Xcode) Setup – Publishable Key

The app must be given the **publishable** key so the Stripe Payment Sheet can run.

1. Open the project in Xcode.
2. Open **AppConstants.swift** (under Utilities or similar).
3. Find:
   ```swift
   static let stripePublishableKey: String? = nil
   ```
4. Replace with your key in quotes:
   - Test: `static let stripePublishableKey: String? = "pk_test_xxxxxxxx"`
   - Live: `static let stripePublishableKey: String? = "pk_live_xxxxxxxx"`
5. Save and rebuild the app.

**Important:** For App Store builds, use your **live** publishable key (`pk_live_...`). For TestFlight or local testing, `pk_test_...` is fine.

---

## 6. Optional – Apple Pay

If you want Apple Pay in the Payment Sheet:

1. In Stripe Dashboard: **Settings → Payment methods → Apple Pay** and follow the steps to add your domain (and run the domain verification file on your site if required).
2. In the Apple Developer account: create an **Merchant ID** and enable **Apple Pay** for the app’s App ID if needed.  
The app already uses Stripe’s Payment Sheet; once Apple Pay is enabled in Stripe and on the device, it can appear as an option automatically.

---

## 7. How the Flow Works (End to End)

| Step | What happens |
|------|----------------|
| 1 | Customer fills cart and taps **Place Order** in the app. |
| 2 | App creates the order via your API (Vercel) and gets an order ID. |
| 3 | App calls **POST /api/stripe/create-payment-intent** with `orderId` and `amount` (cents). |
| 4 | Backend creates a Stripe **PaymentIntent**, stores `orderId` in metadata, returns **client_secret** to the app. |
| 5 | App shows the **Stripe Payment Sheet** (card fields / Apple Pay). |
| 6 | Customer pays. Stripe processes the payment. |
| 7 | Stripe sends **payment_intent.succeeded** to your webhook URL. |
| 8 | Webhook handler updates the order in the database (e.g. sets `stripe_payment_intent_id`, status **Confirmed**). |
| 9 | App shows **Order confirmed** and can clear the cart. The customer sees the order in **My Orders**; the business sees it in **Admin** as confirmed and paid. |

---

## 8. Checklist for the Client

- [ ] Stripe account created and (for live) verified.
- [ ] **STRIPE_SECRET_KEY** and **STRIPE_WEBHOOK_SECRET** set in Vercel and project redeployed.
- [ ] Webhook added in Stripe with URL `https://<your-vercel-domain>/api/stripe-webhook` and events **payment_intent.succeeded** (and **checkout.session.completed** if using payment links).
- [ ] **stripePublishableKey** set in **AppConstants.swift** (publishable key only), app rebuilt.
- [ ] Test: place an order in the app, pay with a test card (e.g. `4242 4242 4242 4242`), confirm order appears as paid in Admin and in My Orders.

Once these are done, the **complete Stripe checkout process** is set up for the client: customers pay in the app, and orders are marked paid automatically via the webhook.
