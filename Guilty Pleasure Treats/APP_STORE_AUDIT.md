# App Store Audit — Guilty Pleasure Treats

Audit date: pre-submission. Use this to fix gaps before submitting so the app passes App Store review.

---

## Critical (must fix or app will be rejected)

| # | Item | Status | Action |
|---|------|--------|--------|
| 1 | **App Icon 1024×1024** | ❌ Missing | `Assets.xcassets/AppIcon.appiconset/` has no image files. Add a 1024×1024 PNG (no transparency). Required for submission. |
| 2 | **Privacy Policy URL** | ❌ Missing | If the app collects data (account, orders, phone), you must provide a working Privacy Policy URL in App Store Connect and optionally in-app. |
| 3 | **Support URL** | ❌ Missing | App Store Connect requires a working Support URL (e.g. website or contact page). |

---

## High (likely to cause rejection or issues)

| # | Item | Status | Action |
|---|------|--------|--------|
| 4 | **Deployment target** | ⚠️ Check | Currently **iOS 26.2**. If you need wider installs, set Minimum Deployments to **iOS 17.0** or **18.0** in Xcode (target → General). |
| 5 | **Placeholder / config URLs** | ⚠️ Configure | Before release, set real endpoints: `AppConstants.imageGenerationBaseURL`, `StripeService` baseURL. Remove or replace any URL containing `"your-"` so the app works in production. |
| 6 | **Unused entitlements** | ✅ Fixed | iCloud/CloudKit removed from entitlements (app doesn’t use them). Push Notifications kept. |
| 7 | **Debug / logging** | ✅ Fixed | `print("Payment failed: ...")` in StripeService removed for production. |
| 8 | **aps-environment** | ⚠️ At submit | Entitlements use `development`. When you archive for App Store, use a **distribution** provisioning profile so `aps-environment` is **production**. |

---

## Recommended (guidelines and best practice)

| # | Item | Status | Action |
|---|------|--------|--------|
| 9 | **Sign in with Apple** | ⬜ If applicable | If you add Google or another third-party login, you must also offer Sign in with Apple (Guideline 4.8). Email/password only does not require it. |
| 10 | **Privacy manifest** | ⬜ If required | If you use certain APIs (e.g. required reason API list), add a Privacy manifest (e.g. PrivacyInfo.xcatalog). Check [Apple’s documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files). |
| 11 | **No secrets in app** | ✅ Design | Stripe secret key must stay on your backend. App only uses publishable key and backend URL; no hardcoded secrets found. |
| 12 | **Export compliance** | ✅ Set | `ITSAppUsesNonExemptEncryption` = false in Info.plist (standard TLS only). |

---

## Already in place ✅

- **Bundle ID**: com.bradleyvirtualsolutions.Guilty-Pleasure-Treats  
- **Version**: 1.0 (1)  
- **Display name & copyright** in Info.plist  
- **NSPhotoLibraryUsageDescription** and **NSCameraUsageDescription**  
- **UIBackgroundModes**: remote-notification  
- **Launch screen** (generated)  
- **Code signing**: Automatic, team set  
- **Orientations** for iPhone and iPad  
- **iPad multitasking**: UIRequiresFullScreen = false  

---

## App Store Connect (before Submit for Review)

- [ ] **Screenshots** for required device sizes (e.g. 6.7", 6.5", 5.5"); no placeholder text.
- [ ] **Description** matches app (bakery ordering, custom cake, AI designer).
- [ ] **Keywords** and **Subtitle** (30 chars) filled.
- [ ] **Age Rating** questionnaire completed (likely 4+).
- [ ] **Pricing** and availability set.
- [ ] **Privacy Policy URL** and **Support URL** added and working.

---

## Pre-submission test list

- [ ] **Archive** with **Release** and install on a **physical device**.
- [ ] Run through main flows (browse → cart → checkout and/or AI designer → confirm).
- [ ] Test with **airplane mode**; app should handle no network without crashing.
- [ ] Confirm **Firebase** and **Stripe** use production config and keys (no test keys in production build).
- [ ] Confirm no **debug logs** or **test credentials** in the shipped build.

---

## Summary

| Severity | Count | Next step |
|----------|--------|-----------|
| Critical | 3 | Add app icon, Privacy Policy URL, Support URL. |
| High | 4 | Set deployment target and real API URLs; use production push when submitting. |
| Recommended | 3 | Add Sign in with Apple if you add other social login; add Privacy manifest if needed. |

Address all **Critical** and **High** items, then run the pre-submission tests and fill App Store Connect metadata before submitting.
