# App notifications

Push notifications use **Apple APNs** (no Firebase). The app and backend are wired for:

- **Admin:** new-order and new-message push (after device token is registered).
- **Customer:** order-status push when admin updates an order.

## Backend (Vercel)

### Environment variables (APNs)

Set these in Vercel → Project → Settings → Environment Variables:

| Variable | Description |
|----------|-------------|
| `APNS_KEY_P8` | Contents of your .p8 key file (Apple Developer) |
| `APNS_KEY_ID` | Key ID |
| `APNS_TEAM_ID` | Team ID |
| `APNS_BUNDLE_ID` | App bundle ID (e.g. `com.example.GuiltyPleasureTreats`) |
| `APNS_SANDBOX` | `true` for development, omit or `false` for production |

Without these, push sending is skipped (no crash); handlers still run.

### Endpoints

- **POST /api/push/register** — Register device token. Body: `{ "deviceToken": "hex string" }`. Requires auth (Bearer or session). Saves to `push_tokens` (one token per user; admin flag from session).

### When push is sent

1. **New message (contact form)** — After a contact message is submitted, admin device tokens (where `is_admin = true`) receive a “New message” push.
2. **Order status update** — When admin (or owner) updates order status via PATCH /api/orders/update-status, the customer’s device token (if registered) receives an “Order update” push.
3. **New order** — `notifyNewOrder()` exists in `api/lib/apns.js` but is **not** called yet; the order-creation handler (POST /api/orders) would need to call it once that endpoint is implemented.

## iOS app

- **AppDelegate:** Requests notification permission and registers for remote notifications; passes device token to `NotificationService.setDeviceToken()`.
- **NotificationService:** Registers the token with the backend when the user is signed in (`registerPushTokenWithBackend()`), stores in-app notifications, and exposes `pendingPushAction` for tap handling.
- **RootView:** On `pendingPushAction` — `.openOrder` switches to Orders tab; other types (new order, new message, low inventory) open Admin.
- **Notification center (bell):** Home screen bell opens `NotificationCenterView`; list is persisted; tap routes to order, messages, or inventory as appropriate.
- **Settings:** User can trigger “request permission and register” from the app.

## Database

- **push_tokens** — Created by `scripts/run-missing-tables.js`. Columns: `user_id` (FK to users), `device_token`, `is_admin`, `updated_at`. One row per user (upsert on register).

## Flow summary

1. User signs in → app calls `registerPushTokenWithBackend()` → POST /api/push/register stores token and `is_admin`.
2. Customer submits contact form → backend inserts message, fetches admin tokens, calls `notifyNewMessage()` → admins get push.
3. Admin updates order status → backend updates order, fetches customer token, calls `notifyOrderStatusUpdate()` → customer gets push.
4. User taps push → app receives notification, adds to in-app center, sets `pendingPushAction` → RootView opens Orders tab or Admin.

## Email newsletter (Resend)

Admin → **Business Settings** → **Marketing** → **Email newsletter** calls **GET/POST `/api/admin/newsletter`** (routed in `api/[[...path]].js` → `api-src/admin/newsletter.js`). Recipients are distinct emails from **orders** plus **non-admin user** accounts, **excluding** addresses in **`newsletter_suppressions`** (marketing opt-out).

**Opt-out**

- **App:** Settings → **Email** → turn off **Email newsletters & offers** (signed-in customers). `PATCH /api/users/me` with `{ "marketingEmailOptIn": false }` inserts the account email into `newsletter_suppressions`.
- **Email link:** Each send replaces `{{UNSUBSCRIBE_URL}}` in HTML with `GET /api/newsletter/unsubscribe?token=…` (HMAC-signed). **Run** `scripts/run-missing-tables.js` (or create `newsletter_suppressions` manually) on Neon before first use.

| Variable | Description |
|----------|-------------|
| `RESEND_API_KEY` | Resend API key (also used as fallback HMAC secret for unsubscribe tokens if `NEWSLETTER_UNSUBSCRIBE_SECRET` is unset) |
| `NEWSLETTER_UNSUBSCRIBE_SECRET` | Optional; preferred secret for signing unsubscribe links |
| `NEWSLETTER_PUBLIC_BASE_URL` or `PUBLIC_APP_URL` | Public site URL for unsubscribe links (e.g. `https://guilty-pleasure-treats.vercel.app`). If unset, `https://$VERCEL_URL` is used on Vercel. |
| `NEWSLETTER_FROM_EMAIL` or `RESEND_FROM_EMAIL` | Verified sender (domain verified in Resend) |
| `NEWSLETTER_MAX_SENDS` | Optional; max sends per request (default 150, cap 500) |
| `BLOB_READ_WRITE_TOKEN` | Required for **Upload Canva design** (stores PNG/JPEG/PDF on Vercel Blob; public URL is embedded in HTML). |

Without these, the API returns **503** with a clear error; the app shows it in the newsletter screen.

### Checklist (Resend dashboard)

1. **API key** — Create a key in Resend → API Keys; set `RESEND_API_KEY` on Vercel (Production + Preview). Send-only keys work for `/emails` but cannot call read-only APIs like listing domains.
2. **From address** — `NEWSLETTER_FROM_EMAIL` must use a **verified domain** (Resend → Domains → add `guiltypleasuretreats.com` or your real domain and complete DNS). If Resend returns *“domain is not verified”*, the domain is missing or DNS is not propagated yet.
3. **Sandbox test** — To confirm the key works before DNS is ready, temporarily set `NEWSLETTER_FROM_EMAIL` to `onboarding@resend.dev` and send to `delivered@resend.dev` (Resend test recipient). Switch back to your real `From` after the domain is verified.

Vercel: `RESEND_API_KEY` cannot be marked “sensitive” for the **Development** environment; use a local `.env.local` for `vercel dev` or rely on Preview/Production.
