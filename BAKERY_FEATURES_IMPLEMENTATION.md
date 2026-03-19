# Bakery Features Implementation Guide

This document lists what was added and what you need to wire in the iOS app and existing API.

---

## 1. Backend (done)

### Schema (run once)

- **Option A:** In Neon SQL Editor, run `scripts/add-bakery-features-schema.sql`
- **Option B:** `node --env-file=.env.neon scripts/run-bakery-features-schema.js`

Adds:

- **orders:** `pickup_time`, `ready_by`, `tip_cents`, `tax_cents`, `stripe_payment_intent_id`, `status` (default `pending`)
- **business_settings:** table with `key`, `value_json` (lead_time_hours, business_hours, min_order_cents, tax_rate_percent)
- **products:** `is_available` (default true), `available_from`

### New API endpoints

| Method | Path | Purpose |
|--------|------|--------|
| PATCH/POST | `/api/orders/update-status` | Body: `{ orderId, status?, pickup_time?, ready_by? }`. Status: pending, confirmed, in_progress, ready, completed, cancelled. |
| POST | `/api/stripe/refund` | Body: `{ orderId, amountCents?, reason? }`. Admin only. Full refund if amountCents omitted. |
| GET | `/api/analytics/export` | Query: `from`, `to` (YYYY-MM-DD). Returns CSV of orders. Admin only. |
| GET/PUT | `/api/settings/business-hours` | GET returns lead_time_hours, business_hours, min_order_cents, tax_rate_percent. PUT updates (admin). |

**Note:** Handlers use `require('../../api/lib/cors')`, `require('../../api/lib/auth')`, `require('../../api/lib/db')`. If your `api/lib` exports different names (e.g. `withCors` vs `cors`, or no `getAuth`), adjust the new API files accordingly.

---

## 2. iOS app – what to add

### 2.1 Order model (`Models/Order.swift`)

Add properties (and decode from API if using Codable):

```swift
var status: String?           // "pending" | "confirmed" | "in_progress" | "ready" | "completed" | "cancelled"
var pickupTime: Date?
var readyBy: Date?
var tipCents: Int?
var taxCents: Int?
```

Display label for status:

```swift
var statusDisplay: String {
    switch status?.lowercased() {
    case "pending": return "Pending"
    case "confirmed": return "Confirmed"
    case "in_progress": return "In progress"
    case "ready": return "Ready for pickup"
    case "completed": return "Completed"
    case "cancelled": return "Cancelled"
    default: return status ?? "Pending"
    }
}
```

### 2.2 VercelService – new methods

Add to `VercelService.swift` (use your existing base URL and auth):

```swift
func updateOrderStatus(orderId: String, status: String?, pickupTime: Date?, readyBy: Date?) async throws {
    var body: [String: Any] = ["orderId": orderId]
    if let s = status { body["status"] = s }
    if let d = pickupTime { body["pickup_time"] = ISO8601DateFormatter().string(from: d) }
    if let d = readyBy { body["ready_by"] = ISO8601DateFormatter().string(from: d) }
    try await post("/orders/update-status", body: body)
}

func refundOrder(orderId: String, amountCents: Int? = nil, reason: String? = nil) async throws {
    var body: [String: Any] = ["orderId": orderId]
    if let a = amountCents { body["amountCents"] = a }
    if let r = reason { body["reason"] = r }
    try await post("/stripe/refund", body: body)
}

func fetchBusinessHours() async throws -> BusinessHoursSettings {
    try await get("/settings/business-hours")
}

func updateBusinessHours(leadTimeHours: Int?, businessHours: [String: String?]?, minOrderCents: Int?, taxRatePercent: Double?) async throws {
    var body: [String: Any] = [:]
    if let v = leadTimeHours { body["lead_time_hours"] = v }
    if let v = businessHours { body["business_hours"] = v }
    if let v = minOrderCents { body["min_order_cents"] = v }
    if let v = taxRatePercent { body["tax_rate_percent"] = v }
    try await put("/settings/business-hours", body: body)
}

func exportOrdersCSV(from: Date? = nil, to: Date? = nil) async throws -> Data {
    var query = ""
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    if let f = from { query += "from=\(fmt.string(from: f))" }
    if let t = to { query += (query.isEmpty ? "" : "&") + "to=\(fmt.string(from: t))" }
    let path = "/analytics/export" + (query.isEmpty ? "" : "?\(query)")
    return try await getRaw(path) // ensure this returns Data
}
```

Add a small model for business hours if you don’t have one:

```swift
struct BusinessHoursSettings: Codable {
    var lead_time_hours: Int?
    var business_hours: [String: String?]?
    var min_order_cents: Int?
    var tax_rate_percent: Double?
}
```

### 2.3 Order detail (customer) – show status and pickup time

In `Views/Orders/OrderDetailView.swift`:

- Show `order.statusDisplay` (e.g. a status badge or text).
- If `order.pickupTime != nil` or `order.readyBy != nil`, show “Pickup: &lt;formatted date&gt;” or “Ready by: &lt;formatted date&gt;”.
- Optionally show tip/tax if you display order totals.

### 2.4 Admin – order status and refund

In the admin order detail (e.g. `AdminTabViews` or order detail sheet):

- **Status picker:** Dropdown or segmented control with: Pending, Confirmed, In progress, Ready, Completed, Cancelled. On change, call `VercelService.shared.updateOrderStatus(orderId:order.id, status: newValue, pickupTime: nil, readyBy: nil)`.
- **Pickup / ready by:** Date picker and “Update” that calls `updateOrderStatus` with `pickupTime` or `readyBy`.
- **Refund button:** “Refund order” that confirms, then calls `VercelService.shared.refundOrder(orderId: order.id)`. Optionally support partial refund (amount field) and pass `amountCents`.

### 2.5 Admin – business hours and lead time

- New screen or section “Business hours” that:
  - Loads `fetchBusinessHours()` and shows lead time (hours), min order, tax rate, and a simple representation of business_hours (e.g. mon–sun with time strings).
  - Saves via `updateBusinessHours(...)`.

Use these values in checkout to:

- Validate pickup time is within business hours and at least `lead_time_hours` in the future.
- Show min order and tax in cart/checkout.

### 2.6 Checkout – pickup time, tip, tax

- **Pickup time:** Add a date/time picker for “When do you want to pick up?”. Send `pickup_time` (and optionally `ready_by`) when creating the order. Validate against business hours and lead time (from `fetchBusinessHours()`).
- **Tip:** Add tip options (e.g. 0%, 10%, 15%, 20%) or custom amount. Store `tip_cents` on the order and include in payment total if you collect tip via Stripe.
- **Tax:** Load `tax_rate_percent` from business settings; compute `tax_cents` from subtotal and send with the order. Show “Tax” line in checkout summary.

Ensure your **order creation** API (e.g. `orders.js` or checkout flow) accepts and persists `pickup_time`, `ready_by`, `tip_cents`, `tax_cents`, and `status` (default `pending`), and that Stripe payment intent or session is stored as `stripe_payment_intent_id` on the order for refunds.

### 2.7 Product availability

- In **menu / product list:** Filter out products where `is_available == false` (and optionally `available_from > today` if you use it). Grey out or hide unavailable items.
- In **admin:** Add a toggle or field per product to set `is_available` and optionally `available_from`. Call your existing products API if it supports PATCH, or add a PATCH handler that updates these fields.

### 2.8 Analytics export (admin)

- Add an “Export orders” or “Reports” action that calls `exportOrdersCSV(from:to:)` (optionally with date range from pickers), then share or save the returned CSV (e.g. via share sheet or write to Files).

---

## 3. Existing API adjustments (if needed)

- **orders (create):** When creating an order (e.g. in `orders.js` or Stripe success flow), set `status = 'pending'`, and persist `pickup_time`, `ready_by`, `tip_cents`, `tax_cents` from the request. Store `stripe_payment_intent_id` (or charge id) from Stripe so refunds work.
- **orders (get one):** Ensure GET order by id returns `status`, `pickup_time`, `ready_by`, `tip_cents`, `tax_cents` so the app can display them.
- **products (list):** Include `is_available` and `available_from` so the app can filter or show “Available from &lt;date&gt;”.
- **business_settings:** If you already have a different table or key for “main” settings, either point `api/settings/business-hours.js` at it or merge the new fields into your existing GET/PUT.

---

## 4. File summary

| Added | Path |
|-------|------|
| Schema SQL | `scripts/add-bakery-features-schema.sql` |
| Schema runner | `scripts/run-bakery-features-schema.js` |
| Order status update | `api-src/orders/update-status.js` |
| Stripe refund | `api-src/stripe/refund.js` |
| Analytics CSV export | `api-src/analytics/export.js` |
| Business hours GET/PUT | `api-src/settings/business-hours.js` |
| Order extension (status/tip/tax display) | `Guilty Pleasure Treats/Models/Order+BakeryFeatures.swift` |
| Business hours model | `Guilty Pleasure Treats/Models/BusinessHoursSettings.swift` |

**Order+BakeryFeatures.swift** compiles only after you add `status`, `pickupTime`, `readyBy`, `tipCents`, `taxCents` to your `Order` model (and decode them from the API).

After running the schema and syncing `api-src` to `api`, deploy and then implement the iOS and any order-creation/GET changes above.
