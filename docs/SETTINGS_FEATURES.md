# Settings features – confirmation

All settings flows are wired end-to-end. Summary and fixes applied.

---

## Customer app: Settings (SettingsView)

| Feature | How it works |
|--------|----------------|
| **Appearance** | Picker for theme (system / light / dark). Stored in `@AppStorage("settings.appearance")`. |
| **Notifications** | Toggle “Order updates & promotions”. On enable, calls `NotificationService.shared.requestPermissionAndRegister()`. |
| **Email** | When signed in: toggle “Email newsletters & offers” → `PATCH /api/users/me` with `marketingEmailOptIn`; server updates `newsletter_suppressions`. |
| **Contact** | Mailto link, Instagram link, “Send a message in app” → sheet with `ContactView()`. |
| **Legal** | NavigationLinks to Privacy Policy and Terms of Service (`DocumentView` with `LegalContent`). |
| **About** | Description, version, build, Support link, Instagram, credits. |
| **Sign out** | Shown when `auth.currentUser != nil`. Calls `try? auth.signOut()`. |
| **Delete account** | Shown when signed in. Presents confirmation dialog; on confirm calls `auth.deleteAccount()`. Error shown in alert. |

**Fix applied:** Delete account section was defined but not included in the List, and there was no confirmation dialog or error alert. The section is now in the List and a `.confirmationDialog` + `.alert` were added so delete is confirmable and errors are shown.

---

## Admin: Business Settings (AdminSettingsView)

| Feature | API | Status |
|--------|-----|--------|
| **Load** | GET `/api/settings/business` | ✅ Routed → `api-src/settings/business.js` |
| **Save** | PATCH `/api/settings/business` (admin) | ✅ Same handler |

Fields: store hours, delivery radius, tax rate, minimum order lead time, contact email/phone, store name, Cash App, Venmo, delivery fee, shipping fee. Load on appear; Save toolbar button calls `viewModel.saveBusinessSettings(settings)`.

---

## Admin: Business hours (BusinessHoursSettingsView)

| Feature | API | Status |
|--------|-----|--------|
| **Load** | GET `/api/settings/business-hours` | ✅ **Fixed** – route was missing; added to path router |
| **Save** | PUT `/api/settings/business-hours` (admin) | ✅ Same route |

Lead time (hours), min order (cents), tax rate (%). Load in `.task` and `.refreshable`; “Save changes” calls `viewModel.updateBusinessHours(...)`.

**Fix applied:** `api/[[...path]].js` had no entry for `settings/business-hours`. Added `'settings/business-hours': 'settings/business-hours.js'` to the file map and the corresponding branch in `getPathKey()` so GET/PUT `/api/settings/business-hours` hit `api-src/settings/business-hours.js`.

---

## Admin: Custom cake options (AdminCustomCakeOptionsView)

| Feature | API | Status |
|--------|-----|--------|
| **Load** | GET `/api/settings/custom-cake-options` | ✅ Routed → `api-src/settings/custom-cake-options.js` |
| **Save** | PATCH `/api/settings/custom-cake-options` (admin) | ✅ Same handler |

Sizes, flavors, frostings, toppings. Load on appear and when `customCakeOptions` changes; Save calls `viewModel.saveCustomCakeOptions(...)`.

---

## Backend (Neon)

All of the above use the `business_settings` table, keyed by:

- `main` – used by both **Business Settings** (full store/delivery/tax/fees) and **Business hours** (lead time, business_hours, min_order_cents, tax_rate_percent). The two handlers merge/update the same JSON.
- `custom_cake_options` – sizes, flavors, frostings, toppings.

Ensure `scripts/run-missing-tables.js` has been run so `business_settings` exists and has the expected columns.
