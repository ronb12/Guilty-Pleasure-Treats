# Neon database — create / update tables

The app expects PostgreSQL tables in your **Neon** project. Use the migration script so everything exists and missing columns are added.

## One command (recommended)

1. Install deps: `npm install`

2. **Either** pull your production DB URL from Vercel **or** use the Neon CLI (no `.env.neon` file needed).

### Option A — Vercel env file

Pull from Vercel (creates `.env.neon` — **do not commit**):

```bash
vercel env pull .env.neon --environment=production
```

Ensure the file contains a usable DB URL. The migration script accepts, in order: `POSTGRES_URL`, `DATABASE_URL`, **`DATABASE_URL_UNPOOLED`**, `NEON_POOL_URL`.

If **`vercel env pull`** leaves `POSTGRES_URL` / `DATABASE_URL` **empty** but sets `DATABASE_URL_UNPOOLED`, migrations still work. For **runtime** and cleaner pulls, set a **non-empty pooled** URL in Vercel (Production):

1. [Neon Console](https://console.neon.tech) → your project → **Connect** → choose **Pooled** / **Connection pooling** (hostname contains `pooler`).
2. [Vercel](https://vercel.com) → your project → **Settings** → **Environment Variables** → Production → add or edit **`DATABASE_URL`** (or **`POSTGRES_URL`**) with that pooled string. Redeploy so serverless picks it up.

Alternatively set **`NEON_POOL_URL`** to the pooled string (see `api/lib/db.js`).

```bash
npm run neon:migrate
```

### Option B — Neon CLI (recommended if you live in Neon Console / CLI)

1. One-time: `npx neonctl auth` and `npx neonctl set-context --org-id … --project-id …` (see [NEON_CLI_CONNECT.md](./NEON_CLI_CONNECT.md)).
2. From project root:

   ```bash
   npm run neon:migrate:cli
   ```

   This sets `POSTGRES_URL` from `npx neonctl connection-string --role-name neondb_owner` and runs `scripts/run-missing-tables.js`.

You should see `All missing tables are ready.` and a line like `Verified 19/19 core tables...`.

## Without Vercel CLI

1. In [Neon Console](https://console.neon.tech) → your project → **Connection details**, copy the connection string.
2. In your terminal:

   ```bash
   export POSTGRES_URL='postgresql://...'
   npm run neon:run-schema
   ```

## What gets created

`scripts/run-missing-tables.js` runs `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` for:

19 core tables: `users`, `sessions`, `password_reset_tokens`, `orders`, `products`, `custom_cake_orders`, `ai_cake_designs`, `admin_messages`, `contact_messages`, `contact_message_replies`, `cake_gallery`, `product_categories`, `customers`, `push_tokens`, `events`, `reviews`, `promotions`, `business_settings`, `order_idempotency`.

Promotions extras (if an old DB): `updated_at`, `min_subtotal`, `min_total_quantity`, `first_order_only`.  
Orders extras: `promo_code`, `loyalty_points_awarded`, etc.

**Products — sizes:** `products.size_options` (`JSONB`, default `[]`) stores per-size labels and prices (e.g. Small / Large). Added by the script above; if your DB predates this, run `npm run neon:migrate` or paste `scripts/sql/add-products-size-options.sql` into the Neon SQL Editor.

## Optional: SQL only

If you prefer the Neon **SQL Editor**, you can still run small fixes, e.g. `scripts/sql/fix-promotions-updated-at.sql` or `scripts/sql/add-products-size-options.sql`, but the Node script is the full source of truth.

## Troubleshooting

- **`password authentication failed`** — wrong connection string or branch.
- **`permission denied for schema public`** — use a role that can `CREATE TABLE` (Neon default owner is fine).
- **Vercel still errors on a column** — re-run `npm run neon:migrate` after deploy; safe to run multiple times.
