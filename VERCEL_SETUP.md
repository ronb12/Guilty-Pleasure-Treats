# Vercel setup – do this once

Your app is already deployed and **AppConstants.vercelBaseURLString** is set to:

**https://guilty-pleasure-treats.vercel.app**

To get products and orders working (and optional image uploads), set up Neon and optionally Blob.

**App login (after running the seed script):** Email `ronellbradley@hotmail.com` · Password `password1234` — see [Login information](#login-information-after-seeding) below for details.

### Neon: connection string vs REST URL

- **This project uses the Postgres connection string** for the API (e.g. `postgresql://user:password@ep-....neon.tech/neondb?sslmode=require`). Set it as **`POSTGRES_URL`** in Vercel and in local scripts. Get it from **Vercel → Storage → Neon → Connection details** (or Neon dashboard).
- **Neon also exposes a REST API** at a URL like:
  - **REST base URL (your Neon):** `https://ep-square-glade-ak1cscz3.apirest.c-3.us-west-2.aws.neon.tech/neondb/rest/v1`  
  That REST URL is for HTTP/PostgREST-style access (with API key). Do **not** put it in `POSTGRES_URL` — the API expects a `postgresql://...` connection string. If you use the REST API from another client, you’ll need the API key from the Neon dashboard.

- **Neon Auth URL (your project):** `https://ep-square-glade-ak1cscz3.neonauth.c-3.us-west-2.aws.neon.tech/neondb/auth`  
  This is Neon’s auth endpoint for this database. The app’s sign-in uses the **Vercel API** (`/api/auth/login`), which reads from the `users` and `sessions` tables in Neon via `POSTGRES_URL`; the app does not call the Neon Auth URL directly.
- **Neon Auth JWKS URL (for JWT verification):** `https://ep-square-glade-ak1cscz3.neonauth.c-3.us-west-2.aws.neon.tech/neondb/auth/.well-known/jwks.json`  
  Public keys (Ed25519) for verifying JWTs issued by Neon Auth. Use this if you integrate Neon Auth and need to validate tokens on the API.

### Using Neon Auth for app sign-in

To use **Neon Auth** (Better Auth) for login and sign-up instead of the built-in email/password + sessions table:

1. **Enable Neon Auth** in your Neon project and get your auth base URL (e.g. `https://ep-....neonauth..../neondb/auth`).
2. In **Vercel** → your project → **Settings** → **Environment Variables**, add:
   - **`NEON_AUTH_URL`** = your Neon Auth base URL (e.g. `https://ep-square-glade-ak1cscz3.neonauth.c-3.us-west-2.aws.neon.tech/neondb/auth`).
3. Run the migration so the API can link Neon Auth users to your `users` table: in Neon SQL Editor, run the contents of **`api/migrate-neon-auth.sql`** (adds `neon_auth_id` column).
4. **Redeploy** the API. After that, **Sign In** and **Sign Up** in the app are proxied to Neon Auth; the API returns a JWT and the app uses it for all authenticated requests. The API verifies the JWT using the JWKS URL above.

If `NEON_AUTH_URL` is not set, the app continues to use the existing flow (email/password against the `users` table and session UUIDs).

- **Quick link – your Neon SQL Editor** (run schema + admin user in one go):  
  [Neon SQL Editor – neondb](https://console.neon.tech/app/projects/tiny-wave-77244048/branches/br-delicate-dust-akt1zfg1/sql-editor?database=neondb)  
  **One-time setup:** Open that link, then copy the **entire** contents of **`api/neon-setup.sql`** into the editor and run it. That creates all tables and adds the admin user (ronellbradley@hotmail.com / password1234).

- **Automation (GitHub Actions):** Push this repo to GitHub, add **POSTGRES_URL** as a repository secret (Settings → Secrets and variables → Actions), then go to **Actions → "Neon setup" → Run workflow**. The workflow runs the schema + admin user for you. See `.github/workflows/neon-setup.yml`.

---

## Option A: Neon via CLI (recommended)

In your **terminal** (so the browser can open for login):

1. **One-time auth**
   ```bash
   npx neonctl auth
   ```
   Complete the login in the browser.

2. **Run setup (schema + admin user) with Neon CLI**
   - **If you already have a Neon project** (e.g. `tiny-wave-77244048`):
     ```bash
     ./scripts/neon-setup-cli.sh tiny-wave-77244048
     ```
   - **Or create a new project** and run setup:
     ```bash
     ./scripts/neon-setup-cli.sh
     ```
   This uses `neonctl` to get the connection string, then runs `api/neon-setup.sql` (all tables + admin user). You can then sign in with **ronellbradley@hotmail.com** / **password1234**.

3. **Connect Neon to Vercel**
   - **Vercel Dashboard** → your project → **Storage** → **Create Database** → **Neon** → connect an existing Neon project (paste the connection string or link the project),  
   **or**
   - **Settings** → **Environment Variables** → add `POSTGRES_URL` = the connection string (from the script output or `npx neonctl connection-string`).

4. **Redeploy** so the API gets the env var: `npx vercel --prod`

---

## Option B: Neon via Vercel dashboard

## 1. Add Neon Postgres

1. Open: **https://vercel.com/ronell-bradleys-projects/guilty-pleasure-treats/stores**
2. Click **Create Database** (or **Add Storage**).
3. Choose **Neon** (Postgres).
4. Create the database (name e.g. `guilty-pleasure-treats-db`).
5. Connect it to your project **guilty-pleasure-treats** so the env var **POSTGRES_URL** is added.

---

## 2. Run the schema in Neon

**Important:** Use the **full** `api/schema.sql` file (not a shortened version). It must include the **users** and **sessions** tables so that sign up / sign in works in the app.

### Sign-in: why it might not work

Sign-in uses **email + password** (no username). It only works when:

1. **`POSTGRES_URL`** is set in Vercel to your **Neon connection string** (the `postgresql://...` URL from Vercel → Storage → Neon → Connection details). Do **not** use the Neon REST API URL here.
2. **Schema has been run** in Neon so the **users** and **sessions** tables exist (see step 2 above).
3. You have an account: either **Sign up** in the app (tap "Need an account? Sign up" on the sign-in screen), or **seed an admin user** and use that email/password:
   - From the project root: `POSTGRES_URL='postgresql://...' node scripts/seed-admin-user.js`  
   - That creates/updates **ronellbradley@hotmail.com** with password **password1234** (change in the script if you prefer).
4. **Redeploy** after adding or changing `POSTGRES_URL` so the API uses the new env (e.g. **Deployments** → ⋯ → Redeploy, or `npx vercel --prod`).

If you see **"Database not configured"** or **"Database error"**, fix `POSTGRES_URL` and redeploy. If you see **"Invalid email or password"**, create an account (Sign up) or run the seed script, then try again.

**Login still fails even though the user exists in Neon?**  
The app checks the password with bcrypt. If you only ran `api/neon-setup.sql`, the admin row may have a hash that doesn’t match `password1234`. **Reset the admin password** so it definitely matches:

1. Get your Neon **connection string** (Vercel → Storage → Neon → Connection details; use the `postgresql://...` URL).
2. From the project root run:
   ```bash
   POSTGRES_URL='postgresql://user:password@host/neondb?sslmode=require' node scripts/seed-admin-user.js
   ```
   (Replace with your real connection string.)
3. Try signing in again with **ronellbradley@hotmail.com** / **password1234**.

### Login information (after seeding)

After you run **`scripts/seed-admin-user.js`** (with `POSTGRES_URL` set), you can sign in to the app with:

| | |
|---|---|
| **Email** | `ronellbradley@hotmail.com` |
| **Password** | `password1234` |

This user is an **admin** (can manage products, orders, and settings in the app). To use a different email or password, edit `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `scripts/seed-admin-user.js`, then run the script again.

Alternatively, use **Sign up** in the app to create a new account with any email and password (no seed script needed).

1. In the same **Stores** page, open your **Neon** store.
2. Go to the **SQL** or **Query** tab (Neon dashboard or the link Vercel gives you).
3. Copy the **entire** contents of **`api/schema.sql`** and paste into the SQL editor.
4. Run the script (Execute / Run).

```sql
-- Run this once in Neon (Vercel Dashboard → Storage → Neon → SQL Editor)
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price DECIMAL(10,2) NOT NULL,
  image_url TEXT,
  category TEXT NOT NULL,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_sold_out BOOLEAN NOT NULL DEFAULT false,
  stock_quantity INT,
  low_stock_threshold INT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  fulfillment_type TEXT NOT NULL,
  scheduled_pickup_date TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'Pending',
  stripe_payment_intent_id TEXT,
  manual_paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  estimated_ready_time TIMESTAMPTZ,
  custom_cake_order_ids JSONB,
  ai_cake_design_ids JSONB
);

CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON products(is_featured);
```

---

## 3. (Optional) Add Vercel Blob for images

Image upload (product images, gallery) needs a Blob store linked to the project so **BLOB_READ_WRITE_TOKEN** is set.

**If you already created a store via CLI** (e.g. `vercel blob store add guilty-pleasure-treats-blob`), you still need to **link** it to the project so the token is added:

1. Open **Vercel Dashboard** → [vercel.com/dashboard](https://vercel.com/dashboard) → select your team/account.
2. Go to **Storage** (left sidebar, or **Stores** in older UI).
3. Find your Blob store (e.g. **guilty-pleasure-treats-blob**). If it’s not linked to the project:
   - Open the store → **Connect to project** (or **Settings** → connect to **guilty-pleasure-treats**).
   - Choose environments: **Production**, **Preview**, and **Development** (so the token is available in all).
4. If you don’t have a store yet: **Create Database** / **Add Storage** → **Blob** → create the store, then connect it to **guilty-pleasure-treats** and apply to all environments.

After linking, Vercel will add **BLOB_READ_WRITE_TOKEN** to the project’s environment variables. Then **redeploy** (see section 4) so the API can use it for uploads.

---

## 4. Redeploy (if you added env vars after deploy)

If you added Neon or Blob **after** the last deploy, trigger a new deploy so the functions get the new env vars:

- **Vercel Dashboard** → your project → **Deployments** → **⋯** on latest → **Redeploy**  
  or run in the project root:  
  `npx vercel --prod`

---

After this, the app will use **https://guilty-pleasure-treats.vercel.app** for products, orders, and (with Blob) image uploads.
