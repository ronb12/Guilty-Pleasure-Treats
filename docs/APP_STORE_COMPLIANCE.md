# App Store compliance — Guilty Pleasure Treats

This document confirms what is in place for App Store compliance and what you must complete in **App Store Connect** and in **production config** so the app can pass review.

---

## ✅ In the app (already compliant)

| Requirement | Status | Where |
|-------------|--------|--------|
| **Sign in with Apple (Guideline 4.8)** | ✅ | Email/password and Sign in with Apple both offered; entitlement `com.apple.developer.applesignin`; `LoginView` + `AuthService.signInWithApple`. |
| **Privacy Policy & Terms** | ✅ | In-app in Settings/Legal: `LegalContent.swift` (Privacy Policy and Terms of Service); no `[placeholder]` in user-facing text. |
| **Usage descriptions** | ✅ | `Info.plist`: `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription` for photos/camera (custom cake, AI design). |
| **Export compliance** | ✅ | `ITSAppUsesNonExemptEncryption` = `false` (no custom crypto). |
| **Identity** | ✅ | Display name, version (1.0), build (1), copyright (© 2026 Bradley Virtual Solutions) in Info.plist. |
| **Push Notifications** | ✅ | `UIBackgroundModes` = `remote-notification`; entitlements `aps-environment` (use **production** for App Store build). |
| **iPad** | ✅ | `UIRequiresFullScreen` = `false` for multitasking. |
| **No App Tracking Transparency** | ✅ | App does not track users across other companies’ apps/sites; no ATT prompt required. |
| **Checkout default** | ✅ | Default payment is **Pay at Pickup** so a reviewer can place an order without using Card/Stripe. |

---

## ⚠️ Optional in code / backend (review risk only if used)

| Item | Risk | Recommendation |
|------|------|----------------|
| **Card (Stripe) / Apple Pay at checkout** | If the reviewer selects “Card (Stripe)” or “Apple Pay”, the app calls your backend for a PaymentIntent. If `POST /api/.../create-payment-intent` is not implemented or fails, **2.1 (broken feature)**. | Either (a) implement that endpoint on Vercel and test, or (b) leave as-is: default is Pay at Pickup so the main path works; reviewers can still try Stripe. If you prefer to avoid any Stripe path in review, hide the Card/Apple Pay options in `CheckoutView` until the backend is ready. |
| **AI Cake Designer** | `imageGenerationBaseURL` is still a placeholder (`your-image-api.com`). The app **fails gracefully** with “Invalid API configuration” (no crash). | Either wire a real AI image API or leave as-is; the error message is clear. You can also hide the AI Designer from the main nav until ready. |

---

## ⬜ You must do in App Store Connect

These cannot be done in code; they are required for submission and for passing compliance checks.

| Item | Action |
|------|--------|
| **Privacy Policy URL** | Required when you collect account/order data. Add a **live URL** in App Store Connect (App Information → Privacy Policy URL). Can be the same text as in-app (e.g. host the policy on your site or use a simple page). |
| **Support URL** | Add a **working** Support URL in App Store Connect (e.g. your website or contact page). The app uses `supportURLString` and `contactEmailString` in Settings; keep those working. |
| **App icon** | 1024×1024 PNG in `Assets.xcassets/AppIcon.appiconset/`. |
| **Screenshots** | Required for each device size (e.g. 6.7", 6.5", 5.5"). No placeholder or misleading text. |
| **Description & keywords** | Describe the real app (bakery, ordering, custom cakes, rewards). No misleading or keyword-stuffed text. |
| **Age rating** | Complete the questionnaire (likely 4+). |
| **Pricing & availability** | Set free or paid and regions. |

---

## Pre-submission checklist

- [ ] **Backend:** Production API returns real products (menu not empty); test account can sign in and place an order (e.g. Pay at Pickup or Cash App).
- [ ] **Links:** Support URL and Instagram (`gp_treats`) open correctly; contact email is correct.
- [ ] **Stripe (if keeping Card/Apple Pay visible):** Either implement `create-payment-intent` on Vercel and test, or accept that reviewers might hit an error if they choose Card.
- [ ] **Build:** Archive with **Release**; use **production** provisioning profile so `aps-environment` is `production` for Push.
- [ ] **No secrets:** No API keys or test credentials in the app bundle; use production config for Stripe/Firebase if applicable.
- [ ] **App Store Connect:** Privacy Policy URL, Support URL, screenshots, description, keywords, age rating, and pricing set.

---

## Guideline references (summary)

- **2.1 App Completeness:** No crashes, broken links, or non-functional features in the main user path. Defaulting checkout to Pay at Pickup keeps the primary path working.
- **4.2 Minimum Functionality:** App provides real utility; avoid “coming soon” or broken flows. Real menu and orders from your backend.
- **4.3 Spam:** No template or duplicate apps; content is specific to Guilty Pleasure Treats.
- **4.8 Sign in with Apple:** If you offer other third-party sign-in (e.g. email/password), you must also offer Sign in with Apple. ✅ Implemented.
- **5.1.1 Privacy:** Privacy Policy and data handling. In-app policy + live URL in App Store Connect required.

With the above in place (in-app compliance ✅, optional Stripe/AI handled or hidden, and App Store Connect fields filled), the app can pass App Store compliance checks.
