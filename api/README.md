# Guilty Pleasure Treats – Vercel API

Serverless API for products, orders, and image uploads. Uses **Neon Postgres** and **Vercel Blob** when configured.

## Setup

1. **Deploy** to Vercel (e.g. connect this repo or `vercel` in project root).
2. **Neon:** Vercel → Project → Storage → Create Database → Neon. This sets `POSTGRES_URL`.
3. **Schema:** Run `api/schema.sql` in Neon’s SQL Editor. [Open SQL Editor (neondb)](https://console.neon.tech/app/projects/tiny-wave-77244048/branches/br-delicate-dust-akt1zfg1/sql-editor?database=neondb) — or use Vercel → Storage → Neon → SQL Editor. Or via Neon CLI: `./scripts/neon-setup-cli.sh tiny-wave-77244048`. Or from project root: `POSTGRES_URL='...' node scripts/run-neon-setup.js`
4. **Blob (optional):** Vercel → Storage → Create → Blob. Sets `BLOB_READ_WRITE_TOKEN` for `/api/upload`.

### Neon schema (full)

| Table | Purpose |
|-------|---------|
| `products` | Menu items (name, price, category, is_featured, is_sold_out, is_vegetarian, …) |
| `orders` | Orders (items, fulfillment_type, status, payment, …) |
| `users` | Auth (email, password_hash, is_admin, points) |
| `sessions` | Login sessions (references users) |
| `business_settings` | Single row: store hours, tax, contact, Cash App, etc. |
| `promotions` | Promo codes (discount type, value, valid dates) |
| `custom_cake_orders` | Custom cake requests (size, flavor, frosting, message, price) |
| `ai_cake_designs` | AI cake design orders |
| `cake_sizes` | Admin-managed sizes for Custom Cake Builder |
| `cake_flavors` | Admin-managed flavors |
| `frosting_types` | Admin-managed frosting options |

- **New database:** run `api/schema.sql` once.
- **Existing database (older schema):** run `api/migrate-neon.sql` to add `is_vegetarian` and cake-options tables.
- **Verify:** run `api/verify-neon.sql` to list tables and confirm `products.is_vegetarian` exists.

## Install dependencies

From the **project root** (where `package.json` is):

```bash
npm install
```

## Endpoints

- `GET /api/health` – Health check
- `GET /api/products` – List products (`?category=...&featured=true`)
- `GET /api/products/:id` – Single product
- `GET /api/orders` – List orders (`?userId=...` for user filter)
- `POST /api/orders` – Create order (JSON body)
- `GET /api/orders/:id` – Get order
- `PATCH /api/orders/:id` – Update order (`status`, `manualPaidAt`, `estimatedReadyTime`)
- `POST /api/upload` – Upload image; body `{ "base64": "...", "pathname": "products/xyz.jpg" }`; returns `{ "url": "..." }`

## iOS app

Set `AppConstants.vercelBaseURLString` to your Vercel URL (e.g. `https://your-app.vercel.app`) so the app uses this API for products, orders, and uploads.
