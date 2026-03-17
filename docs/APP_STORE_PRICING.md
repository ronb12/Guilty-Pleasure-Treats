# Set the app price in App Store Connect

You set the **App Store price** for **Guilty Pleasure Treats** in App Store Connect. The app code does not control this.

## Where to set it

1. Go to [App Store Connect](https://appstoreconnect.apple.com).
2. Open **My Apps** → select **Guilty Pleasure Treats** (create the app first if needed, with bundle ID `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`).
3. In the left sidebar, go to **Pricing and Availability** (under the app name, not under a version).

## Options

| Choice | When to use |
|--------|--------------|
| **Free** | Best for a bakery/ordering app: customers download free and pay for orders (Stripe, etc.). Revenue comes from orders, not the app. |
| **Paid (price tier)** | Use only if you want customers to pay once to download the app (e.g. $0.99, $2.99). You pick a **price tier**; Apple shows the local price per country. |

## Steps to set the price

### Free

1. **Pricing and Availability** → under **Price**, choose **Free**.
2. Under **Availability**, leave **Make this app available** checked and add the countries/regions where the app should appear (or “All”).
3. Save.

### Paid

1. **Pricing and Availability** → under **Price**, choose **Add Pricing** (or edit existing).
2. Select a **price tier** (e.g. Tier 1 ≈ $0.99 USD). Apple maps tiers to local currencies.
3. Set **Availability** (countries/regions).
4. Save.

## Recommendation for Guilty Pleasure Treats

Use **Free** so users can install the app at no cost and pay for orders (products, custom cakes) through your existing payment flow. No in-app purchase is required for selling physical goods.

## When it applies

- **TestFlight:** TestFlight builds are always free for testers; this price does not affect TestFlight.
- **App Store:** This price is used when you submit a version for **App Store** review and release. You can change it later in **Pricing and Availability** for future versions or anytime.

## Summary

| What | Where |
|------|--------|
| App Store price (free or paid) | App Store Connect → Your App → **Pricing and Availability** |
| In-app product prices (bakery items) | Your backend/API and app (already in the app) |
