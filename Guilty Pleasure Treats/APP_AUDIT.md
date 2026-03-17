# Guilty Pleasure Treats — App Audit

**Audit date:** March 2026  
**Scope:** iOS app (Xcode project), configuration, security, App Store readiness, and codebase health.

**Fixes applied (post-audit):** App entry switched to RootView; SwiftData/fatalError removed; Firebase configured at launch; deployment target set to iOS 17.0; promo code at checkout added; Sign in with Apple added (entitlement + AuthService + LoginView); Stripe/AI URLs centralized in AppConstants; owner email comment improved. Privacy Policy URL and Support URL still must be set in App Store Connect. Duplicate folder `GuiltyPleasureTreats/` (no space) is legacy; the active app is `Guilty Pleasure Treats/` (with space).

---

## 1. Executive summary

| Area | Status | Summary |
|------|--------|--------|
| **App entry & UX** | ✅ Fixed | App now launches **RootView** (full bakery: Home, Cart, Menu, Orders, Profile). Firebase configured in app init. |
| **Configuration** | ✅ Improved | Stripe/AI URLs in AppConstants; owner email comment. Replace placeholder URLs before production. |
| **Security** | ✅ Good | No hardcoded secrets; Sign in with Apple added per Guideline 4.8. |
| **App Store** | ⚠️ Partial | Icon done; deployment target 17.0; Privacy Policy URL and Support URL set in App Store Connect. |
| **Code quality** | ✅ Solid | SwiftData/fatalError removed. MVVM, clear structure. |
| **Feature completeness** | ✅ Fixed | Promo code field at checkout; discount applied to order total. |

---

## 2. App entry and user experience

### 2.1 Current launch flow

- **Entry point:** `Guilty_Pleasure_TreatsApp.swift` → `AppearanceWrapper` → **ContentView()**.
- **ContentView** shows: AI Cake Designer, Settings, Legal (Privacy/Terms), and a SwiftData “Items” list (template data).
- **RootView** (tabs: Home, Cart, Rewards, Orders, Account with full menu, cart, checkout, Firebase) is **never used** as the root.

**Recommendation:** Decide which experience is the product:

- If the **full bakery app** (menu, cart, checkout, orders) is the product → switch the app entry to **RootView()** and remove or repurpose ContentView/SwiftData Items.
- If the **simplified app** (AI Cake Designer + Settings + Legal) is intentional → document it and ensure all links (e.g. Support, Instagram) and flows are correct.

### 2.2 Admin access

- Admin is gated: 5-tap on splash **and** sign-in with **isAdmin** in Firestore (or email in `ownerEmails`).
- **`AppConstants.ownerEmails`** is **empty** — no one gets admin automatically until you add an email or set `isAdmin` in Firestore for a user.

**Action:** Add at least one owner email, e.g.  
`static let ownerEmails: [String] = ["your@email.com"]`

---

## 3. Configuration and placeholders

| Item | Location | Current value | Action |
|------|----------|----------------|--------|
| Stripe backend | `StripeService.swift` | `https://your-backend.com` | Replace with real backend (e.g. Vercel/Cloud Functions) that creates PaymentIntents. |
| AI image API | `AppConstants.imageGenerationBaseURL` | `https://your-image-api.com/generate` | Replace with real endpoint; optional API key via `ImageGenerationService` init. |
| Owner admin | `AppConstants.ownerEmails` | `[]` | Add owner email(s). |
| Support URL | `AppConstants.supportURLString` | `https://www.bradleyvirtualsolutions.com` | Confirm correct; also set in App Store Connect. |
| Tax rate | `AppConstants.taxRate` | `0.08` | Can be overridden by Admin Business Settings (Firestore) once set. |

### 3.1 Firebase

- **GoogleService-Info.plist** is not in the repo (correct for security). It must be added in Xcode for the app to run with Firebase (Auth, Firestore, Storage, Messaging).
- Ensure the plist matches the Firebase project and bundle ID.

---

## 4. Security

- **Secrets:** No API keys or secrets hardcoded in source. Stripe and image generation use configurable base URLs.
- **.gitignore:** Excludes build artifacts, `.vercel`, and (commented) suggests excluding `GoogleService-Info.plist` — good practice.
- **Entitlements:** Only Push Notifications (`aps-environment`); no unnecessary capabilities.
- **Auth:** Firebase Auth; admin enforced via `isAdmin` / `ownerEmails`. No Sign in with Apple yet (required by App Store if other third‑party login is offered).

---

## 5. App Store readiness

| Requirement | Status | Notes |
|-------------|--------|--------|
| App icon 1024×1024 | ✅ | `AppIcon.png` in `AppIcon.appiconset`. |
| Bundle ID | ✅ | `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats` |
| Version / Build | ✅ | 1.0 (1) in Info.plist |
| Display name / Copyright | ✅ | Set in Info.plist |
| Deployment target | ⚠️ | **iOS 26.2** — very high; consider **iOS 17.0** or **18.0** for wider support. |
| Privacy descriptions | ✅ | Photo Library, Camera in Info.plist |
| Push / encryption | ✅ | `remote-notification`, `ITSAppUsesNonExemptEncryption = false` |
| Privacy Policy URL | ⬜ | Required; set in **App Store Connect** (and optionally in-app). |
| Support URL | ⬜ | Set in App Store Connect; in-app uses `supportURLString`. |
| Sign in with Apple | ⬜ | If you keep email/Google login, add Sign in with Apple (Guideline 4.8). |

---

## 6. Code and architecture

### 6.1 Structure

- **Models:** Product, Order, UserProfile, Promotion, BusinessSettings, CustomCakeOrder, AICakeDesignOrder, CartItem, Reward, etc.
- **Views:** Per-feature (Home, Menu, Cart, Checkout, Orders, Admin, Settings, Legal, AICakeDesigner, etc.).
- **ViewModels:** Match main flows; AdminViewModel covers products, orders, customers, special orders, promos, analytics, settings.
- **Services:** FirebaseService, AuthService, StripeService, CartManager, NotificationService, ImageGenerationService.

### 6.2 Notable issues

- **fatalError in app entry:** `Guilty_Pleasure_TreatsApp` uses `fatalError` if SwiftData `ModelContainer` fails. Consider logging and showing an error UI instead of crashing.
- **Promotions:** Admin can create/edit/delete promos; **Checkout has no “promo code” field** and no logic to apply discounts. Either add promo application at checkout or document as “admin-only / future.”
- **Duplicate folder:** `GuiltyPleasureTreats/` (no space) exists alongside `Guilty Pleasure Treats/` (with space). One is the active Xcode app; the other may be legacy. Consolidate or remove to avoid confusion.

### 6.3 Debug / production

- No `print`/`debugPrint` found in the main app target (only `fatalError` in SwiftData init). Safe for production from a logging perspective.

---

## 7. Feature checklist

| Feature | Implemented | Notes |
|---------|-------------|--------|
| Menu & products | ✅ | Firebase; admin CRUD, sold out, inventory (optional). |
| Cart | ✅ | CartManager. |
| Checkout | ✅ | Contact, fulfillment, payment method; Stripe placeholder backend. |
| Orders | ✅ | Customer history; admin list and status updates. |
| Rewards / points | ✅ | Firestore; completed orders add points. |
| Custom cake builder | ✅ | Firestore + Storage. |
| AI Cake Designer | ✅ | Image generation service (URL placeholder). |
| Admin: products, orders | ✅ | Full. |
| Admin: customers, analytics, settings | ✅ | From orders; revenue/orders by day; business settings. |
| Admin: special orders (custom/AI) | ✅ | List only. |
| Admin: promotions | ✅ | CRUD; **not applied at checkout**. |
| Appearance (light/system/dark) | ✅ | Settings + AppearanceWrapper. |
| Legal (Privacy/Terms) | ✅ | In-app; URLs for App Store still needed. |
| App icon | ✅ | In assets. |

---

## 8. Recommended actions (priority)

1. **Decide root UI:** Use **RootView** (full app) or keep **ContentView** and document.
2. **Set owner admin:** Add at least one email to `AppConstants.ownerEmails`.
3. **Replace placeholders:** Stripe backend URL, AI image API URL (and key if needed).
4. **Lower deployment target:** e.g. iOS 17.0 or 18.0 in Xcode.
5. **App Store Connect:** Set Privacy Policy URL, Support URL, screenshots, description, Sign in with Apple if required.
6. **Optional:** Add promo code field and discount logic at checkout; or document that promos are admin-only for now.
7. **Optional:** Replace SwiftData `fatalError` with error handling / user-facing message.

---

## 9. Files referenced in this audit

- `Guilty Pleasure Treats/Guilty_Pleasure_TreatsApp.swift`
- `Guilty Pleasure Treats/ContentView.swift`
- `Guilty Pleasure Treats/Views/RootView.swift`
- `Guilty Pleasure Treats/Utilities/AppConstants.swift`
- `Guilty Pleasure Treats/Info.plist`
- `Guilty Pleasure Treats/Guilty_Pleasure_Treats.entitlements`
- `Guilty Pleasure Treats/Services/StripeService.swift`
- `Guilty Pleasure Treats/Services/ImageGenerationService.swift`
- `Guilty Pleasure Treats/Assets.xcassets/AppIcon.appiconset/`
- `APP_STORE_CHECKLIST.md`
- `.gitignore`
