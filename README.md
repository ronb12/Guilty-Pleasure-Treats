# Guilty Pleasure Treats

Bakery ordering stack: **SwiftUI app** (iOS / iPadOS; Mac build is limited for payments), **serverless API** on [Vercel](https://vercel.com), **PostgreSQL** on [Neon](https://neon.tech), and optional **Stripe** for cards (in-app Payment Sheet and admin-hosted Checkout links). A small **static site** in `website/` is served at the project root on the same deployment. The **iOS and native Mac** targets share the same `Guilty Pleasure Treats/` sources—see [docs/MAC_IOS_APP_PARITY.md](docs/MAC_IOS_APP_PARITY.md).

## Repository layout

| Path | Purpose |
|------|---------|
| `Guilty Pleasure Treats/` | Xcode project and SwiftUI app source |
| `api-src/` | API route handlers (canonical copy; imported by the catch-all route) |
| `api/` | Vercel `api/` tree: `[[...path]].js` catch-all, shared `api/lib/`, and synced handlers (see below) |
| `website/` | Marketing/static pages (`index.html`, etc.); Vercel `outputDirectory` |
| `scripts/` | Deploy sync, Neon helpers, smoke tests |

## API on Vercel

- **Entry:** `api/[[...path]].js` maps `/api/*` to modules under `api-src/` (dynamic `import()`), which keeps the Hobby **serverless function** count low.
- **Before deploy:** `npm run vercel:sync` copies `api-src/` → `api/` (preserving `api/lib/`), then **removes** `api/stripe/create-checkout-session.js` and `api/stripe/create-payment-intent.js` so those URLs are **only** handled by the catch-all (standalone files under `api/stripe/` would otherwise override the route).
- **Standalone Stripe refund:** `api/stripe/refund.js` remains a separate function (not in the catch-all map).
- **Health check:** `GET /api/health` — JSON includes `database`, `apnsConfigured`, and `apnsSandbox` (env-only; no APNs client loaded).

### Environment variables (Vercel / local)

Set these in the Vercel project (or `.env.local` for `vercel dev`) as needed:

| Variable | Role |
|----------|------|
| `POSTGRES_URL` or `DATABASE_URL` | Neon Postgres connection string |
| `STRIPE_SECRET_KEY` | Optional override; secret can also be stored via **Admin → Business Settings** in the app |
| `CARRIER_TRACKING_WEBHOOK_SECRET` | Optional. Shared secret for `POST /api/webhooks/carrier-tracking` (header `X-Carrier-Tracking-Secret` or `Authorization: Bearer …`). Updates `tracking_*` on an order by `orderId`. |
| `USPS_CLIENT_ID`, `USPS_CLIENT_SECRET` | Optional. [USPS Developer Portal](https://developers.usps.com/getting-started) app credentials (Consumer Key & Secret). Enables hourly **`GET /api/cron/poll-usps-tracking`** for **USPS** shipments (official API; no paid aggregator). |
| `USPS_API_BASE` | Optional. Default `https://apis.usps.com`. Use `https://apis-tem.usps.com` for USPS test (TEM). |
| `PARCEL_TRACKING_POLL_SECRET` or `CRON_SECRET` | Optional. `Authorization: Bearer …` must match one of these to call the USPS poll endpoint (Vercel Cron can use `CRON_SECRET`). |
| Others | JWT/auth, Apple Sign In, Blob upload, etc., per your deployment |

**Parcel tracking:** Orders expose `trackingCarrier` (`ups` \| `fedex` \| `usps`), `trackingNumber`, optional `trackingStatusDetail`, and a computed `trackingUrl`. Use **Admin → Orders → Shipment → Edit** or the **webhook** (e.g. `{ "orderId": "<uuid>", "trackingCarrier": "usps", "trackingNumber": "9400…", … }`). When status text looks like a final delivery, **Shipping** orders can **auto-complete** (loyalty + push).

**USPS auto-poll:** With USPS + cron env vars set, `vercel.json` runs **`/api/cron/poll-usps-tracking`** hourly for open **Shipping** orders where **carrier is usps**, updates `trackingStatusDetail` from the USPS **Tracking** API summary, then applies the same delivery auto-complete logic. **UPS/FedEx** stay manual or webhook-only. Add DB columns with `node scripts/run-missing-tables.js` (or rely on `ensureOrdersOptionalColumns` on first orders request).

**Apple Push (APNs):** Server pushes (orders, order status, loyalty points on completion, contact and thread replies, store messages, events, low inventory, custom cake requests, new reviews, etc.) send only when **all** of these are set in Vercel: `APNS_KEY_P8` (full `.p8` key file contents), `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`. Use `APNS_SANDBOX=true` for development builds against Apple’s sandbox. If any required value is missing, pushes are skipped; `GET /api/health` reports `apnsConfigured: false`.

Never commit real secrets; configure them in Vercel or local env files that are gitignored.

## iOS app

Open `Guilty Pleasure Treats/Guilty Pleasure Treats.xcodeproj` in Xcode. Firebase, Stripe Payment Sheet, and entry-point setup are described in:

`Guilty Pleasure Treats/Guilty Pleasure Treats/PACKAGES_AND_ENTRY.md`

The app talks to the API using the base URL configured in code (e.g. production `https://guilty-pleasure-treats.vercel.app`).

## Website

See `website/README.md`. The Vercel project uses `website` as the static output directory while `/api/*` is handled by serverless routes.

## Scripts

```bash
npm install

# Copy api-src → api before deploy (also runs as Vercel buildCommand)
npm run vercel:sync

# Production deploy (sync + Vercel CLI)
npm run deploy
```

**Neon / DB helpers:** `npm run neon:context`, `npm run neon:connect`, `npm run neon:migrate` (see `package.json`). The repo uses **neonctl 2.22+**; if `connection-string` or `branches` errors, run `npm install` and see `docs/NEON_CLI_CONNECT.md`.

**Smoke checks:**

```bash
npm run test:order-totals
npm run test:api-write-routes
npm run test:product-db
```

## Local API development

Use the [Vercel CLI](https://vercel.com/docs/cli) with a linked project and env vars loaded, for example:

```bash
vercel dev
```

Point the app or `curl` at the local URL Vercel prints (and ensure `POSTGRES_URL` / `DATABASE_URL` is set if you need database-backed routes).

## License

Private project (`"private": true` in `package.json`). All rights reserved unless otherwise noted by the owner.
