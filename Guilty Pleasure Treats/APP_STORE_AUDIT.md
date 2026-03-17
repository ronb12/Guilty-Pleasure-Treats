# App Store Spam / Rejection Risk Audit — Guilty Pleasure Treats

**Date:** March 2026  
**Guidelines in scope:** 4.2 (Minimum Functionality), 4.3 (Spam), 2.1 (App Completeness), metadata and placeholder content.

---

## Summary

The app is a real bakery/ordering product (menu, cart, checkout, orders, rewards, custom/AI cake). Several items that can trigger **4.2** (incomplete/placeholder) or **4.3** (spam-like) rejections were found and addressed or documented below.

---

## Fixes applied

### 1. “Coming soon” / placeholder copy (4.2)

- **Was:** Home screen showed “Featured treats coming soon” when there were no featured products.
- **Risk:** Suggests unfinished or template app.
- **Fix:** Replaced with: “Check out our full menu below for cupcakes, cookies, cakes, and more.” So the empty state is helpful and not “coming soon.”

### 2. Placeholder backend URL (2.1 / 4.2)

- **Was:** `stripeBackendURLString = "https://your-backend.com"`.
- **Risk:** Looks like unreplaced template; Card (Stripe) would always fail.
- **Fix:** Set to your Vercel base URL: `https://guilty-pleasure-treats.vercel.app`.  
- **Note:** Your Vercel API does **not** yet expose `POST /create-payment-intent`. Until it does, “Card (Stripe)” will still fail. Options: (a) add that endpoint on Vercel, or (b) hide or de-emphasize the Stripe option and rely on Cash App / Pay at Pickup for review.

---

## Findings and recommendations

### High priority

| Item | Risk | Recommendation |
|------|------|-----------------|
| **Stripe payment** | 2.1 – Broken feature if reviewer pays with card | Implement `POST /create-payment-intent` on Vercel (amount, currency, orderId → Stripe PaymentIntent client_secret), or remove/hide “Card (Stripe)” until it works. |
| **Sample / fallback data** | 4.3 – Can look like generic template if reviewer only sees sample content | Ensure **production** backend has real products and (if possible) at least one real order for the test account. When API fails or user isn’t signed in, the app shows sample orders/menu; that’s acceptable if the primary path uses real data. |
| **AI cake image** | 4.2 – Feature that always errors | `imageGenerationBaseURL` is still `https://your-image-api.com/generate`. The app already throws “Invalid API configuration” when URL contains `your-`. Either: (1) wire to a real AI image API and test, or (2) hide “AI Cake Designer” from the main flow until ready (e.g. show only in Settings or remove from tab/Home). |

### Medium priority

| Item | Risk | Recommendation |
|------|------|-----------------|
| **Support / Instagram links** | 2.1 – Broken links | Confirm `supportURLString` (bradleyvirtualsolutions.com) and `instagramURLString` (instagram.com/gp_treats) resolve and are correct. Replace if the business uses different URLs. |
| **Orders empty state** | 4.2 | When the API fails, the app shows sample orders and the message “Showing sample orders. Sign in or check your connection to load your orders.” Consider tightening copy to e.g. “Example orders — sign in to see yours” so it’s clearly fallback, not the main experience. |
| **Menu empty state** | 4.2 | If the products API returns empty, the app falls back to `SampleDataService.sampleProducts`. For review, ensure the live API returns real menu items so reviewers see real content first. |

### Low priority / already OK

- **Legal:** Privacy Policy and Terms in `LegalContent.swift` are real content; no literal `[placeholders]` in user-facing text.
- **Info.plist:** Sensible display name, copyright (© 2026 Bradley Virtual Solutions), usage descriptions for photo library and camera. No keyword stuffing.
- **Placeholder images:** Use of `placeholderName: "cupcake.and.candles.fill"` for missing product images is a normal SF Symbol fallback, not spam.
- **App name:** “Guilty Pleasure Treats” is a single, specific name (no repetitive or misleading keywords).

---

## Checklist before submit

- [ ] Backend has real products (menu not empty in production).
- [ ] Stripe: either implement `/create-payment-intent` on Vercel or hide/disable “Card (Stripe)” so no broken payment path.
- [ ] AI Cake Designer: either working with a real image API or hidden until ready.
- [ ] Support and Instagram URLs open correctly.
- [ ] Test account can sign in and place an order (e.g. Cash App or Pay at Pickup).
- [ ] No “coming soon”, “TBD”, or “Lorem” in user-facing strings (already fixed for featured section).
- [ ] App Store Connect: app description and keywords describe the real app (bakery, ordering, rewards); no misleading or stuffed keywords.

---

## Guideline references

- **4.2 Minimum Functionality:** Apps must provide enough utility and work as described; avoid “coming soon” or broken features.
- **4.3 Spam:** No duplicate or template-like apps; content should be substantive and specific to the app.
- **2.1 App Completeness:** No crashes, broken links, or placeholder content in the shipped build.
