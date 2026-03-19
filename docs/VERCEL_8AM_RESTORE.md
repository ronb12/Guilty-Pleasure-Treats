# Vercel 8 AM Restore – What Was Missing and What We Restored

This doc summarizes what was in the **Vercel deployment at 8:00 AM** (commit `b83f27e`, last commit before 8 AM) and what was restored so the repo matches that behavior.

---

## How 8 AM worked

- **No `buildCommand`** in `vercel.json` – no sync step; the API was not overwritten at build time.
- **Single entry:** `api/index.js` re-exported `api/[[...path]].js` (catch-all).
- **Catch-all** `api/[[...path]].js` routed `/api/*` to handlers in **api-src/** via dynamic `import()` (so api-src was never copied into api/).
- **api/lib/** was ESM: `setCors` / `handleOptions` in cors, `sql` / `hasDb` in db, full auth (sessions + Neon JWT), neonAuth, apns.

---

## What was missing (vs 8 AM)

| Item | At 8 AM | After changes (before restore) |
|------|---------|---------------------------------|
| **vercel.json** | No `buildCommand` | Had `buildCommand: "bash scripts/sync-api-for-vercel.sh"` |
| **api/index.js** | Re-exported `[[...path]].js` | Empty |
| **api/[[...path]].js** | Full catch-all routing to api-src | Empty |
| **api-src/health.js** | ESM; `{ ok, service, database, timestamp }` | CommonJS; only `{ ok, status: 'healthy' }` |
| **api-src/index.js** | GET /api returned name, version, endpoints | Empty |
| **api-src/products.js** | ESM; placeholders when no DB; category/featured query; POST (admin); full rowToProduct | CommonJS; no placeholders; no POST; different shape |
| **api/lib/cors.js** | ESM `setCors`, `handleOptions` | CommonJS `withCors` only |
| **api/lib/db.js** | ESM `sql`, `hasDb` | CommonJS |
| **api/lib/auth.js** | ESM: getSession, getTokenFromRequest, sessions, Neon JWT | CommonJS; minimal getAuth only |
| **api/lib/neonAuth.js** | Full Neon Auth (JWKS, verify, getOrCreateUser, sign-in/sign-up proxy) | Empty |
| **api/lib/apns.js** | Full APNs (sendPushNotification, notifyNewOrder, etc.) | Empty |

---

## What we restored

1. **vercel.json** – Removed `buildCommand` so deploy matches 8 AM (no sync).
2. **api/index.js** – Restored re-export of `./[[...path]].js`.
3. **api/[[...path]].js** – Restored full catch-all that dynamically imports from **api-src/** and handles health inline.
4. **api-src/health.js** – Restored ESM handler with `ok`, `service`, `database`, `timestamp`.
5. **api-src/index.js** – Restored GET /api with name, version, endpoints.
6. **api-src/products.js** – Restored ESM: placeholders when no DB, category/featured query, POST (admin), full rowToProduct.
7. **api/lib/cors.js** – Restored ESM `setCors`, `handleOptions`; added `withCors` for backward compatibility.
8. **api/lib/db.js** – Restored ESM `sql`, `hasDb`.
9. **api/lib/auth.js** – Restored ESM: getSession, getTokenFromRequest, createSession, deleteSession, hashPassword, verifyPassword; added async `getAuth(req)` for callers that need `{ userId, isAdmin }`.
10. **api/lib/neonAuth.js** – Restored full Neon Auth (verifyNeonJWT, getOrCreateUserFromNeonPayload, neonAuthSignIn, neonAuthSignUp).
11. **api/lib/apns.js** – Restored full APNs (sendPushNotification, notifyNewOrder, notifyOrderStatusUpdate, notifyNewMessage).

Additionally, so that standalone api handlers work with ESM lib:

- **api/stripe/refund.js**, **api/settings/business-hours.js**, **api/orders/update-status.js**, **api/analytics/export.js** – Converted to ESM and `await getAuth(req)` (these routes were not in the 8 AM catch-all map but exist in the repo).

---

## Products table column names

The 8 AM **api-src/products.js** uses `row.description` and inserts into `description`. If your Neon `products` table uses `product_description` instead of `description`, you may need to adjust the SELECT/INSERT in **api-src/products.js** (or add a migration) to match your schema.

---

## How to deploy

- Open the project in Vercel and deploy from this repo (or push and let Vercel build).
- No build command runs; the catch-all in **api/** loads handlers from **api-src/** at runtime.
- Ensure **api-src/** and **api/lib/** are included in the deployment (they are part of the repo and are deployed with the serverless function).

---

## Rolling back production to the actual 8 AM deployment

If you want production to serve the **exact** deployment that was live at 8 AM (rather than a new build from this repo), use:

- **Vercel Dashboard:** Deployments → find the deployment created ~8 AM → ⋮ → **Instant Rollback** (or Promote to Production).
- **CLI:** `VERCEL_TOKEN=xxx node scripts/list-vercel-deployments.js` to find the deployment, then `vercel rollback <deployment-url-or-id>`.

See **docs/USE_VERCEL_APP_FROM_8AM.md** for step-by-step instructions.
