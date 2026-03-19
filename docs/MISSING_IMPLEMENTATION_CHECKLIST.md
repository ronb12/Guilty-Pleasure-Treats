# Missing implementation checklist

Use this list to finish wiring the bakery features and Vercel deploy. Some steps require editing files that may timeout in the IDE; run from Terminal or try again.

---

## 1. Vercel: include API in every build

So **all** Vercel builds (including Git-based deploys) have the full `api/` folder:

- **Option A:** From project root in Terminal:
  ```bash
  node scripts/ensure-vercel-json.js
  ```
  This writes or merges `buildCommand: "node scripts/sync-api-for-vercel.js"` into `vercel.json`.

- **Option B:** Manually ensure `vercel.json` contains:
  ```json
  {
    "buildCommand": "node scripts/sync-api-for-vercel.js"
  }
  ```
  (You can copy from `vercel.build.json`.)

Then commit `vercel.json`, `api-src/`, and `scripts/sync-api-for-vercel.js` so Vercel runs the sync during build.

---

## 2. Order model (if not already present)

In **`Guilty Pleasure Treats/Models/Order.swift`** (or the main `Order` struct), add these optional properties and CodingKeys if you use Codable:

- `var status: String?`
- `var pickupTime: Date?`
- `var readyBy: Date?`
- `var tipCents: Int?`
- `var taxCents: Int?`

Decode from API snake_case (e.g. `pickup_time`, `ready_by`, `tip_cents`, `tax_cents`).  
`Order+BakeryFeatures.swift` already provides `statusDisplay`, `tipFormatted`, `taxFormatted`; it expects these properties on `Order`.

---

## 3. VercelService (if bakery API calls fail)

**`VercelService+BakeryAPI.swift`** uses:

- `post(_ path: String, body: [String: Any]) async throws`
- `put(_ path: String, body: [String: Any]) async throws`
- `get<T: Decodable>(_ path: String) async throws -> T`
- `getRaw(_ path: String) async throws -> Data`

If your main **`VercelService.swift`** uses different names or no `getRaw`, add thin wrappers there (or in the extension) that call your existing request API.  
Admin **updateOrderStatus(order: Order, status: OrderStatus)** calls `api.updateOrderStatus(orderId: status:)`; the main VercelService should implement that and call `/api/orders/update-status` with the status string (e.g. `status.rawValue`).

---

## 4. Admin UI: wire new views and Refund

### 4.1 Business hours

- **`BusinessHoursSettingsView.swift`** is added. In your Admin tab or settings, add a way to open it, e.g.:
  - `NavigationLink("Business hours", destination: BusinessHoursSettingsView().environmentObject(viewModel))`
- Ensure the Admin view is inside a `NavigationStack`/`NavigationView` so the title and form work.

### 4.2 Export orders CSV

- **`ExportOrdersView.swift`** is added. Add a way to open it from Admin (e.g. Analytics or Orders tab):
  - `NavigationLink("Export CSV", destination: ExportOrdersView().environmentObject(viewModel))`
- On iOS, the share sheet will appear when export completes. On macOS you may need to add a save panel.

### 4.3 Refund button (order detail)

- In the **admin order detail** view (where you have “Mark as paid” or “Payment link”), add a **Refund** action:
  - e.g. `Button("Refund") { Task { await viewModel.refundOrder(orderId: order.id ?? "") } }`
  - Optionally add a confirmation alert or a sheet to enter partial amount/reason.

---

## 5. Add new Swift files to the Xcode project

If the new views are not picked up automatically:

- In Xcode, right‑click the **Views/Admin** group (or appropriate group).
- **Add Files to “Guilty Pleasure Treats”** and select:
  - `BusinessHoursSettingsView.swift`
  - `ExportOrdersView.swift`
- Ensure target membership is checked for your app target.

---

## 6. Deploy and verify

1. Sync and deploy:
   ```bash
   ./scripts/sync-api-for-vercel.sh
   vercel --prod
   ```
2. Run the deployment check:
   ```bash
   VERCEL_TOKEN=xxx node scripts/check-vercel-deployment-vs-app.js
   ```
   You should see builds with 53 api routes and 0 missing.

3. In the app: test Business hours (load/save), Export CSV, and Refund from an order.
