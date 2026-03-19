# Bakery Features — Runbook

Do these steps in order. Use project path **`/Users/ronellbradley/Projects/GuiltyPleasureTreats`** (no space).

---

## Step 1: Run schema in Neon

**Option A – Neon SQL Editor**

1. Open [Neon Console](https://console.neon.tech) → your project → **SQL Editor**.
2. Paste and run the contents of **`scripts/add-bakery-features-schema.sql`**.

**Option B – Node script (if you have POSTGRES_URL)**

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
export POSTGRES_URL='your-neon-connection-string'
node scripts/run-bakery-features-schema.js
```

---

## Step 2: Sync and deploy

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
rsync -a --exclude='lib' api-src/ api/
vercel --prod
```

If `rsync` hits "mmap: Operation timed out", run the sync from a different terminal or after a reboot. Then run `vercel --prod` again.

---

## Step 3: Confirm api/lib exports

New API files use:

- `require('../../api/lib/cors')` → expect `withCors`
- `require('../../api/lib/auth')` → expect `getAuth`
- `require('../../api/lib/db')` → expect `sql`

Open **api/lib/cors.js**, **api/lib/auth.js**, **api/lib/db.js**. If export names differ (e.g. default export or different names), update these files to match:

- **api-src/orders/update-status.js**
- **api-src/stripe/refund.js**
- **api-src/analytics/export.js**
- **api-src/settings/business-hours.js**

---

## Step 4: Wire the app

### 4.1 Order model

In **Models/Order.swift** add (and decode from API if using Codable):

- `var status: String?`
- `var pickupTime: Date?`
- `var readyBy: Date?`
- `var tipCents: Int?`
- `var taxCents: Int?`

Use **Models/Order+BakeryFeatures.swift** for `statusDisplay`, `tipFormatted`, `taxFormatted` (it extends `Order` and uses these properties).

### 4.2 VercelService

Add the methods from **BAKERY_FEATURES_IMPLEMENTATION.md** § 2.2 into **Services/VercelService.swift**, or add **Services/VercelService+BakeryAPI.swift** and implement the methods there using your existing `post`, `get`, `put` (and optionally a `getRaw` for CSV):

- `updateOrderStatus(orderId:status:pickupTime:readyBy:)` — ensure it calls **POST /api/orders/update-status** with body `{ orderId, status?, pickup_time?, ready_by? }`. If you already have `updateOrderStatus(orderId:status:)` with `OrderStatus`, map `OrderStatus` to the API string (e.g. `.pending` → `"pending"`, `.ready` → `"ready"`) and add optional `pickupTime`/`readyBy` parameters.
- `refundOrder(orderId:amountCents:reason:)` — POST **/api/stripe/refund**
- `fetchBusinessHours()` — GET **/api/settings/business-hours** → `BusinessHoursSettings`
- `updateBusinessHours(...)` — PUT **/api/settings/business-hours**
- `exportOrdersCSV(from:to:)` — GET **/api/analytics/export** with query `from`/`to`, return `Data`

**Models/BusinessHoursSettings.swift** is already in the project for the business-hours API.

### 4.3 Order detail (customer)

In **Views/Orders/OrderDetailView.swift**:

- Show **order.statusDisplay** (e.g. a label or badge).
- If **order.pickupTime** or **order.readyBy** is set, show “Pickup: &lt;date&gt;” or “Ready by: &lt;date&gt;”.
- Optionally show **order.tipFormatted** and **order.taxFormatted** in the totals section.

### 4.4 Admin: order status and refund

You already have **AdminViewModel.updateOrderStatus(order:status:)** calling **api.updateOrderStatus(orderId:status:)**. Ensure that calls **POST /api/orders/update-status** with the string status. Add:

- **Pickup / ready by:** In the admin order detail UI, add date pickers and a button that calls `api.updateOrderStatus(orderId: ..., status: nil, pickupTime: date, readyBy: nil)` (or your equivalent with the new parameters).
- **Refund:** A “Refund order” button that confirms, then calls `api.refundOrder(orderId: order.id)`.

### 4.5 Admin: business hours and export

- **Business hours:** New screen or section that loads `fetchBusinessHours()`, shows lead time, business hours, min order, tax rate, and saves with `updateBusinessHours(...)`.
- **Export:** “Export orders” (or “Reports”) that calls `exportOrdersCSV(from:to:)` with optional date range and shares/saves the CSV.

### 4.6 Checkout: pickup time, tip, tax

- Add **pickup time** (and optionally “ready by”) to checkout; send with order creation. Validate against business hours and lead time from **fetchBusinessHours()**.
- Add **tip** (e.g. 0%, 10%, 15%, 20% or custom) and **tax** from **tax_rate_percent**; include in order payload as **tip_cents** and **tax_cents** and in Stripe amount if applicable.

### 4.7 Product availability

- In **menu / product list**, filter or grey out products where **is_available == false** (and **available_from** if you use it).
- In **admin product edit**, add a toggle for **is_available** (and optional **available_from**); call your products API PATCH if it supports these fields.

---

## Quick checklist

- [ ] Schema run in Neon (Step 1)
- [ ] Sync api-src → api and deploy (Step 2)
- [ ] api/lib exports match new handlers (Step 3)
- [ ] Order: status, pickupTime, readyBy, tipCents, taxCents (4.1)
- [ ] VercelService: updateOrderStatus (with pickup/ready), refundOrder, fetchBusinessHours, updateBusinessHours, exportOrdersCSV (4.2)
- [ ] Order detail: status and pickup/ready display (4.3)
- [ ] Admin: status + pickup/ready + refund + business hours + export (4.4, 4.5)
- [ ] Checkout: pickup time, tip, tax (4.6)
- [ ] Products: is_available in menu and admin (4.7)
