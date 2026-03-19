# Guilty Pleasure Treats — App Features

A single reference for all features in the **Guilty Pleasure Treats** mobile app and backend. Use this on the `main` branch (e.g. in GitHub) as the canonical feature list.

---

## 1. Customer-facing features

### Account & auth
- **Login** — Email/password sign in
- **Sign up** — New account registration
- **Sign in with Apple** — Apple ID authentication
- **Forgot / reset password** — Email-based password reset and set-password flow
- **Profile** — View and manage account; delete account

### Catalog & menu
- **Menu** — Browse products by category
- **Product categories** — Category list and filtering
- **Product detail** — Name, description, price, image, add to cart
- **Cake gallery** — Gallery of cake designs/photos
- **Favorites** — Save and view favorite products

### Ordering
- **Cart** — Add/remove items, quantities, view total
- **Checkout** — Customer details, Stripe payment (card)
- **Order confirmation** — Post-purchase confirmation screen
- **Order history** — List of customer’s orders
- **Order detail** — Single order view (items, total, status when available)
- **Order status** — Pending, confirmed, in progress, ready for pickup, completed, cancelled (when backend/app support it)

### Special orders
- **Custom cake builder** — Build a custom cake; options from API (e.g. size, frosting, toppings)
- **AI cake designer** — Generate cake image via AI (generate-image API); place order for the design

### Engagement
- **Events** — View events (title, date, time, location, description)
- **Promotions** — View promotions; apply promo code at checkout
- **Reviews** — View product/app reviews (and optionally submit)

### Loyalty
- **Rewards** — View points balance and redemption options
- **Points** — Earn points on orders; redeem (when supported by backend)

### Contact & support
- **Contact form** — Send a message to the business
- **Contact replies** — View replies from admin in the app

### Other
- **Push notifications** — Opt-in push for order updates and promotions
- **Settings** — App preferences, notifications, account
- **Legal** — Terms of service, privacy policy
- **Low-stock / sold-out** — Product availability and sold-out state (when supported)

---

## 2. Admin-facing features

### Orders
- **Order list** — View all orders (with filters/period when available)
- **Order detail** — View single order (customer, items, total, status)
- **Update order status** — Change status (e.g. pending → confirmed → in progress → ready → completed / cancelled)
- **Mark as paid** — Mark order as manually paid
- **Payment link** — Create/copy Stripe payment link for customer
- **Refund** — Full or partial refund via Stripe (admin only; bakery feature)
- **Create manual order** — Add an order on behalf of a customer
- **Custom cake order detail** — View and manage custom cake orders
- **AI cake design order detail** — View and manage AI cake design orders
- **Order tracking (optional)** — Tracking UI (AdminOrderTrackingSheet, TrackingInfoView) when wired

### Products & menu
- **Product list** — View all products
- **Add product** — Name, description, price, cost, category, featured, vegetarian, image, stock, low-stock threshold
- **Edit product** — Update product details and image
- **Delete product** — Remove product
- **Set sold out** — Mark product as sold out or available
- **Product categories** — Manage categories (when UI is wired)
- **Cake gallery** — Manage gallery items (when UI is wired)

### Customers
- **Customer list** — Derived from orders; view by customer (name, phone, order count, total spent)
- **Saved customers** — List and count from customers API

### Contact & messaging
- **Contact messages** — View incoming contact form messages
- **Mark message read** — Mark contact message as read
- **Reply to contact** — Send in-app reply to customer
- **Admin messages** — Send messages to users (by user id); view sent messages

### Analytics & reporting
- **Analytics summary** — Revenue, order counts, trends (when wired)
- **Period filters** — This week, this month, all time
- **Revenue / order counts by period** — Filtered totals and comparisons
- **Export orders CSV** — Date-range export for accounting (admin only; bakery feature)
- **Share / save CSV** — Share or save exported CSV (iOS share sheet when wired)

### Business settings
- **Business settings** — General business settings from API
- **Business hours & lead time** — View and edit lead time (hours), business hours, min order, tax rate (bakery feature; BusinessHoursSettingsView when wired)
- **Custom cake options** — Manage options for the custom cake builder

### Other admin
- **Promotions** — Manage promotions (when UI is wired)
- **Events** — Add, edit, delete events (when UI is wired)
- **Reviews** — Update/delete reviews (when UI is wired)
- **Push** — Send or manage push notifications (when wired)
- **Upload** — Product image upload (used when adding/editing products)

---

## 3. Backend (API) features

### Auth
- Login, signup, Sign in with Apple
- JWT-based auth; forgot/reset/set password; delete account

### Products & categories
- CRUD-style endpoints for products and product categories
- Product images (upload, URL)

### Orders
- Create order, list orders, get order by id
- Order status in DB; update status (PATCH/POST `/api/orders/update-status`) with optional pickup_time, ready_by
- Manual paid, payment link creation

### Special orders
- Custom cake orders: create, list, get by id
- AI cake designs: create, list, get by id
- Custom cake options: list, update (settings)

### Other content
- Cake gallery, events, promotions (with code validation)
- Contact: messages, replies
- Admin messages, customers, reviews
- Business settings, custom-cake-options

### Payments
- Stripe: create checkout session, create payment intent
- Refund: full or partial (POST `/api/stripe/refund`; admin only)

### Analytics & export
- Analytics summary
- Orders CSV export (GET `/api/analytics/export`; query from/to; admin only)

### Settings
- Business settings
- Business hours: GET/PUT `/api/settings/business-hours` (lead_time_hours, business_hours, min_order_cents, tax_rate_percent)

### Infrastructure
- Health check
- Push (APNS)
- Upload (e.g. product images)
- Database (Neon/Postgres)

---

## 4. Bakery-specific features (implemented or added)

| Feature | Backend | App (when wired) |
|--------|---------|-------------------|
| Order status workflow | ✅ `orders/update-status` | ✅ Admin update status; Order status display |
| Pickup / ready-by | ✅ In schema & update-status | Order model: pickupTime, readyBy |
| Tips & tax on orders | ✅ Schema: tip_cents, tax_cents | Order: tipCents, taxCents; display helpers |
| Business hours & lead time | ✅ `settings/business-hours` GET/PUT | BusinessHoursSettingsView, load/update |
| Refunds | ✅ `stripe/refund` | Admin refund action |
| Export orders CSV | ✅ `analytics/export` | ExportOrdersView, share/save |
| Product availability | ✅ Schema: is_available, available_from | Product sold-out / availability |

---

## 5. Platforms & deployment

- **iOS** — Native Swift/SwiftUI app (iPhone; iPad/Mac when configured)
- **Backend** — Node.js serverless API on Vercel (Neon Postgres, Stripe, APNS)
- **Sync** — `api-src/` → `api/` before deploy (script or `vercel.json` buildCommand)
- **Git** — `main` (or `github/main`) branch; this document lives in `docs/APP_FEATURES.md` for the main branch / GitHub.

---

*Last updated: 2026. For gap analysis and implementation details, see `BAKERY_APP_FEATURE_GAP_ANALYSIS.md` and `BAKERY_FEATURES_IMPLEMENTATION.md`.*
