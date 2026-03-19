# App pages vs 8:00 AM state

Comparison of each app page/screen to the **8:00 AM** version (commit `b83f27e`). Restorations were applied so the **shell** matches 8 AM; per-page content differences are noted below.

---

## Tabs and shell (restored to match 8 AM)

| Item | At 8 AM | Before restore | Now |
|------|---------|----------------|-----|
| **Tab count** | 6 tabs | 5 tabs | **6 tabs** ✓ |
| **Tab order** | Home, Menu, Cart, Rewards, **Orders**, **Account** | Home, Menu, Cart, Rewards, More | **Home, Menu, Cart, Rewards, Orders, Account** ✓ |
| **TabRouter** | `TabRouter.shared`, `selectedTab` (0–5) | Missing (empty file) | **Restored** ✓ |
| **Splash** | 1.4s, 5-tap to show Admin | 2.0s, no 5-tap | **1.4s, 5-tap Admin** ✓ |
| **Splash UI** | Gradient (primary/secondary), progress bar, tagline “Every bite’s a little indulgence” | Solid background, logo + title | **Gradient, progress bar, tagline** ✓ |
| **NotificationService** | `pendingPushAction`, `clearPendingPushAction`, open Order/Admin | Missing | **Stub added** (openOrder, openAdmin) ✓ |
| **Per-tab NavigationStack** | Each tab wrapped in `NavigationStack { … }` | Only some | **Each tab in NavigationStack** ✓ |
| **Tab labels** | `Image` + `Text` | `Label(_, systemImage:)` | **Image + Text** ✓ |

---

## Page-by-page

### 1. Splash
- **Now matches 8 AM:** Logo, gradient, progress bar (1.4s), tagline “Every bite’s a little indulgence”, scale/opacity/float animations, 5-tap to show Admin.

### 2. Home
- **8 AM had:** Hero section, trust strip, promotions, quick actions, featured products, scroll-to-top, notification center link, `HomeNavRoute` (gallery, customCake).
- **Now:** Simpler: logo, promotions banner, custom cake / AI cards, featured products, browse menu. No hero, trust strip, or scroll-to-top.
- **Status:** Structure aligned for main content; hero and extra chrome can be re-added if desired.

### 3. Menu
- **8 AM had:** Full menu (251 lines), categories, products, search/filter likely.
- **Now:** MenuViewModel + list by category, ProductCard, link to ProductDetail. Same idea, slimmer implementation.
- **Status:** Same pages (Menu list → Product detail); content level may differ.

### 4. Cart
- **8 AM had:** Cart view (248 lines), likely CartManager and line items.
- **Now:** CartManager, CartView with empty state and list, checkout CTA.
- **Status:** Same idea (cart + checkout); layout/detail may differ.

### 5. Rewards
- **8 AM had:** RewardsViewModel, `loadPoints()`, sign-in prompt, points card, how-it-works, rewards section, success/error banners.
- **Now:** Sign-in prompt or points from `AuthService.currentUser?.points`, how-it-works.
- **Status:** Same flow (sign in → points); 8 AM had dedicated RewardsViewModel and rewards list.

### 6. Orders (tab 4)
- **8 AM:** Dedicated **Orders** tab (`OrdersView()`).
- **Now:** **Orders** tab with `OrdersView()` (sign-in prompt or order list).
- **Status:** Matches 8 AM (separate Orders tab).

### 7. Account (tab 5)
- **8 AM had:** ProfileView with `auth.authState` (loading / signedIn(user) / signedOut), signedInView, signedOutView, signInCard, legalLinksCard, Settings in toolbar, sheet login, fullScreenCover Admin.
- **Now:** ProfileView with `AuthService.shared`, user header when signed in, list (Orders, Settings, Contact, Legal, Notifications, Admin if admin), Sign in / Sign out.
- **Status:** Same purpose (account + sign in/out + settings); 8 AM used `authState` enum and slightly different layout.

### 8. Settings
- **8 AM:** Contained in ProfileView / separate SettingsView (contact, legal, about, sign out).
- **Now:** SettingsView with appearance, notifications, contact links, legal, about (from your current SettingsView).
- **Status:** Same areas (settings, contact, legal, about); one place may have more sections than the other.

### 9. Admin
- **8 AM:** Shown via 5-tap on splash or push action; fullScreenCover (iOS) / sheet (Mac).
- **Now:** Same (5-tap splash, `showAdmin` → AdminView).
- **Status:** Matches 8 AM.

### 10. Product detail, Checkout, Contact, Legal, Notifications, Login
- **8 AM:** Same screens existed (ProductDetailView, CheckoutView, ContactView, LegalView, NotificationCenterView, LoginView).
- **Now:** Same screens present; content may be more or less detailed.
- **Status:** Same set of pages; parity at flow level.

---

## Summary

- **Tabs and shell:** Restored to match 8 AM: 6 tabs (including Orders and Account), TabRouter, NotificationService stub, splash 1.4s + gradient + progress bar + tagline + 5-tap Admin, per-tab NavigationStack, AppConstants.primary.
- **Pages:** The same main pages exist (Splash, Home, Menu, Cart, Rewards, Orders, Account, Settings, Admin, Product detail, Checkout, Contact, Legal, Notifications, Login). Some screens have a simpler or different layout than the 8 AM version; the app flow and tab structure now match 8 AM.

To fully match 8 AM content on every screen, you’d restore the 8 AM versions of HomeView, MenuView, CartView, RewardsView, ProfileView, and SettingsView from commit `b83f27e` (and ensure any types they depend on exist).
