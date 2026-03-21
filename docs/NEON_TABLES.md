# Neon database — create / update tables

The app expects PostgreSQL tables in your **Neon** project. Use the migration script so everything exists and missing columns are added.

## One command (recommended)

1. Install deps: `npm install`
2. Pull your production DB URL from Vercel (creates `.env.neon` — **do not commit**):

   ```bash
   vercel env pull .env.neon --environment=production
   ```

   Ensure the file contains `POSTGRES_URL` or `DATABASE_URL` (Neon connection string).

3. Run migrations:

   ```bash
   npm run neon:migrate
   ```

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

## Optional: SQL only

If you prefer the Neon **SQL Editor**, you can still run small fixes, e.g. `scripts/sql/fix-promotions-updated-at.sql`, but the Node script is the full source of truth.

## Troubleshooting

- **`password authentication failed`** — wrong connection string or branch.
- **`permission denied for schema public`** — use a role that can `CREATE TABLE` (Neon default owner is fine).
- **Vercel still errors on a column** — re-run `npm run neon:migrate` after deploy; safe to run multiple times.
