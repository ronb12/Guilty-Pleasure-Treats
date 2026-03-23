# Neon database – required tables for the app

All of these tables are created by **one script**:

```bash
node --env-file=.env.neon scripts/run-missing-tables.js
```

Ensure `POSTGRES_URL` (or `DATABASE_URL`) is set, e.g. via `vercel env pull .env.neon --environment=production`.

---

## Tables created by `run-missing-tables.js`

| Table | Purpose |
|-------|--------|
| **users** | Auth (login, admin), referenced by push_tokens and sessions |
| **sessions** | Local session after email/password login |
| **orders** | Checkout orders (pickup/delivery/shipping), admin list, analytics export |
| **products** | Menu products, admin inventory; includes `size_options` (JSONB) for per-size pricing |
| **custom_cake_orders** | Custom cake builder items, linked to orders via `order_id` |
| **ai_cake_designs** | AI cake gallery designs/orders, linked to orders via `order_id` |
| **admin_messages** | Admin → Messages “Send new message” / Sent list |
| **contact_messages** | Contact form submissions, admin messages |
| **contact_message_replies** | Admin in-app replies to contact messages |
| **cake_gallery** | Gallery images (admin-managed) |
| **product_categories** | Menu categories (chips), admin-managed |
| **customers** | Saved customers / address book |
| **push_tokens** | Device tokens for push (requires `users`) |
| **events** | Events / tastings (home screen) |
| **reviews** | Customer reviews (home screen) |
| **business_settings** | Key/value JSON: `main` (hours, tax, lead time), `custom_cake_options` (sizes, flavors, frostings, toppings) |

---

## Optional / other schemas

- **neon_auth** (Better Auth): `neon_auth.user`, `neon_auth.account` – usually created by Neon Auth setup, not by this repo.
- **admin_messages**: Created by `run-missing-tables.js` (see table list above).
- **cake_toppings** / **frosting_types**: Optional; see `scripts/run-add-cake-toppings.js` and `scripts/add-frosting-types.js` if you use separate topping tables instead of `business_settings.custom_cake_options`.

---

## Verifying tables in Neon

1. Open [Neon Console](https://console.neon.tech) → your project → **SQL Editor**.
2. Run: `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;`
3. You should see the tables listed above (and any extras you added).

If you see **relation does not exist** errors from the API, run:

```bash
node --env-file=.env.neon scripts/run-missing-tables.js
```

Then redeploy or retry the request.
