# Bakery Shop App — Feature Gap Analysis

Analysis of **Guilty Pleasure Treats** vs. what a bakery typically needs to **run the full business from the app** (customer + admin).

---

## 1. What the app already has

### Customer-facing
| Area | Features present |
|------|------------------|
| **Auth** | Login, signup, Sign in with Apple, forgot/reset password, profile |
| **Catalog** | Menu (products), product categories, product detail, cake gallery |
| **Ordering** | Cart, checkout (Stripe), order confirmation, order history, order detail |
| **Special orders** | Custom cake builder (options from API), AI cake designer (generate-image API) |
| **Engagement** | Events, promotions (with code), reviews |
| **Loyalty** | Rewards view (points/redemption) |
| **Contact** | Contact form, view contact replies |
| **Other** | Notifications (push), settings, legal (terms/privacy), favorites |

### Admin-facing (from Views + API)
| Area | Features present |
|------|------------------|
| **Orders** | View orders, custom cake order detail, AI cake design order detail; optional tracking UI (AdminOrderTrackingSheet, TrackingInfoView) |
| **Contact** | Contact messages, replies (contact API) |
| **Messaging** | Admin messages to users (admin-messages API) |
| **Backend** | Business settings API, custom-cake-options API, analytics/summary API, customers API, push, upload |

### Backend (API + DB)
- **Auth**: login, signup, Apple, JWT, forgot/reset/set password, delete account  
- **Products & categories**: CRUD-style endpoints  
- **Orders**: create, list, get by id (orders have `status` in DB)  
- **Custom cake orders** & **AI cake designs**: create, list, get by id  
- **Cake gallery**, **events**, **promotions** (with code validation)  
- **Contact**: messages, replies  
- **Admin messages**, **customers**, **reviews**  
- **Settings**: business, custom-cake-options  
- **Stripe**: checkout session, payment intent  
- **Push** (APNS), **upload**, **analytics/summary**, **health**

---

## 2. Gaps for running the full business from the app

### High impact (needed to operate day-to-day)

| Gap | What’s missing | Why it matters |
|-----|----------------|----------------|
| **Order status workflow** | No clear **admin flow to change order status** (e.g. pending → confirmed → in progress → ready → completed) and no **customer-facing status/tracking** in the app. | Staff can’t manage orders end-to-end; customers don’t see “ready for pickup” or similar. |
| **Pickup / delivery scheduling** | No **pickup time** or **delivery window** on orders; no **lead time / “ready by”** for custom or regular orders. | Bakery can’t commit to when orders will be ready; customers can’t choose when to pick up. |
| **Business hours & lead time** | **Business settings** exist in API but it’s unclear if **hours** and **lead time** (e.g. “orders need 24h notice”) are editable from the app and enforced at checkout. | Orders can land for times the shop is closed or with unrealistic turnaround. |
| **Inventory / availability** | No **stock** or **availability** (e.g. “sold out”, “available from date”) on products or daily specials. | Risk of overselling or showing items that aren’t available. |
| **Refunds / payment adjustments** | Only Stripe **payment** creation; no **refund** or **partial refund** flow in app or API. | Disputes and order changes can’t be handled fully from the app. |

### Medium impact (operations + clarity)

| Gap | What’s missing | Why it matters |
|-----|----------------|----------------|
| **Tips** | No **tip** option at checkout or in order total. | Common expectation for bakery/cafe; staff may handle tips offline only. |
| **Tax** | No explicit **tax** calculation or display (e.g. per product or order). | Compliance and accurate totals; may be required depending on jurisdiction. |
| **Delivery vs pickup** | No **delivery** (address, zones, fees) or explicit **pickup vs delivery** choice and pricing. | Limits to pickup-only unless handled elsewhere. |
| **Product management from app** | Products/categories likely managed via API/backend; no clear **admin UI to add/edit products, prices, images**. | Staff may depend on scripts or DB to change menu. |
| **Reporting / export** | **Analytics summary** exists but no clear **sales reports**, **revenue by period**, or **export (e.g. CSV)** for accounting. | Hard to run the business by the numbers from the app. |
| **Multiple admins / roles** | Single admin or unclear **role-based access** (e.g. viewer vs full admin). | Scaling staff and separating duties. |

### Nice to have

| Gap | What’s missing | Why it matters |
|-----|----------------|----------------|
| **Automated order notifications** | Push/APNS and admin messages exist; no clear **automated** “order confirmed”, “ready for pickup”, “out for delivery”. | More communication without manual messages. |
| **SMS / email** | No visible **SMS** or **email** for order updates or receipts. | Some customers prefer email/SMS over in-app only. |
| **Holidays / closed days** | No **holiday calendar** or “closed on date X” in business settings. | Prevents orders for days the shop is closed. |
| **Min order / delivery minimum** | No **minimum order** or **minimum for delivery** in settings or checkout. | Common for delivery and for efficiency. |
| **Customer address book** | **Customers** table and API exist; unclear if **saved addresses** are used at checkout or in profile. | Faster checkout and delivery. |

---

## 3. Summary table

| Category | Status | Notes |
|----------|--------|--------|
| Customer: browse, cart, pay, special orders | ✅ Strong | Menu, cart, Stripe, custom + AI cake |
| Customer: order status / tracking | ⚠️ Partial / missing | Orders have status in DB; no clear admin update + customer view |
| Admin: order management (status, timeline) | ⚠️ Partial | View orders; status workflow and tracking need to be explicit |
| Scheduling (pickup, lead time, hours) | ❌ Gap | No pickup/delivery time, unclear lead time in app |
| Inventory / availability | ❌ Gap | No stock or availability in app flow |
| Payments: refunds / adjustments | ❌ Gap | No refund flow in app/API |
| Tips & tax | ❌ Gap | Not present in current flow |
| Delivery (zones, fees, choice) | ❌ Gap | Pickup-only unless added |
| Admin: product/menu management | ⚠️ Unclear | API exists; admin UI for CRUD not evident |
| Reporting & export | ⚠️ Partial | Analytics/summary; no clear reports/export |
| Multi-admin / roles | ⚠️ Unclear | Not clearly modeled |
| Automated notifications | ⚠️ Partial | Push + admin messages; no automated order-lifecycle messages |

---

## 4. Recommended priorities (to run full business from the app)

1. **Order status workflow**  
   - API: PATCH (or equivalent) **order status** (e.g. pending → confirmed → in progress → ready → completed).  
   - Admin app: list orders, filter, and **update status**.  
   - Customer app: **order detail** shows current status and, if desired, simple tracking (e.g. “Ready for pickup”).

2. **Pickup time / lead time**  
   - Add **pickup_time** or **ready_by** (and optionally **lead_time_days/hours** in business settings).  
   - Enforce at checkout (e.g. only allow times within business hours and lead time).  
   - Show in admin order view and in customer order detail.

3. **Business hours & lead time in app**  
   - Ensure **business settings** include hours and lead time and that these are **editable in admin** and **used** when creating orders and validating pickup times.

4. **Refunds**  
   - Add **refund** (and optionally partial refund) via Stripe in API; expose in admin (e.g. from order detail).

5. **Tips and tax**  
   - Add **tip** (e.g. at checkout) and **tax** (e.g. per item or order) in cart/checkout and in order totals; store and show in admin/customer views.

6. **Product availability**  
   - Add **availability** or **stock** (or “available from” date) to products; respect in menu and checkout and, if needed, in admin product management.

7. **Reporting / export**  
   - Expand **analytics** (e.g. sales by day/week, revenue, top products) and add **export** (e.g. CSV) for accounting.

After these, delivery (zones, fees), multi-admin roles, and automated order notifications will round out running the full business from the app.

---

*Generated from codebase review: Swift views/ViewModels/services, api-src routes, scripts and schema (Neon), and PROJECT_COPIES_COMPARISON / DEPLOY docs.*
