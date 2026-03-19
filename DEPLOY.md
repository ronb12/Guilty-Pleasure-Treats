# Full deploy (Vercel)

## 1. Sync API into deployable folder

**Use the project folder without a space:** `GuiltyPleasureTreats` (not "Guilty Pleasure Treats").

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
```

Vercel builds from the `api/` folder. Handlers are maintained in `api-src/`. Sync before every deploy:

```bash
# Recommended: shell script tries rsync --no-mmap → cp loop → Node (retries + chunked fallback)
./scripts/sync-api-for-vercel.sh

# Or run steps yourself:
rsync -a --exclude='lib' --no-mmap api-src/ api/   # or omit --no-mmap if unsupported
# If rsync times out:
node scripts/sync-api-for-vercel.js   # Node uses stream copy + retries + chunked fallback
```

This copies all routes from `api-src/` into `api/` and leaves `api/lib/` (db, auth, cors, apns) unchanged.

**If `api/` has empty files** (e.g. after a failed sync), restore them from `api-src/` by running in **Terminal.app** (not Cursor):

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
./scripts/restore-api-from-api-src.sh
```

That copies every file from `api-src/` into `api/` (excluding `lib`), so `api/` matches `api-src/` 100%.

## 2. Environment variables (Vercel)

In the Vercel project **Settings → Environment Variables**, set:

- **POSTGRES_URL** or **DATABASE_URL** – Neon connection string
- **JWT_SECRET** (or **AUTH_SECRET**) – secret for JWT signing
- **STRIPE_SECRET_KEY** – for checkout session (optional if not using Stripe)
- **VERCEL_URL** – usually set by Vercel (used for Stripe redirect URLs)
- **APPLE_BUNDLE_ID** / **APPLE_CLIENT_ID** – for Sign in with Apple (optional)
- **APNS_KEY_ID**, **APNS_TEAM_ID**, **APNS_PRIVATE_KEY**, **APNS_BUNDLE_ID** – for push (optional)

## 3. Deploy

```bash
# Sync then deploy
node scripts/sync-api-for-vercel.js
vercel --prod
```

**Git-based deploys:** So the deployment includes the full `api/` folder, add a build step that runs the sync. Run `node scripts/ensure-vercel-json.js` from the project root (or copy `vercel.build.json` to `vercel.json`). Then every Vercel build will run the sync and populate `api/` from `api-src/`. See **docs/MISSING_IMPLEMENTATION_CHECKLIST.md** for full wiring steps.

Or add to `package.json` scripts:

```json
"scripts": {
  "vercel:sync": "node scripts/sync-api-for-vercel.js",
  "deploy": "npm run vercel:sync && vercel --prod"
}
```

Then: `npm run deploy`.

## 4. Check the build (empty files / missing features)

Before or after deploy, use the Vercel CLI to confirm the build has no empty API files and expected routes are present:

**Local check (recommended before deploy):**

```bash
node scripts/check-vercel-build.js           # run vercel build, then check api + output
node scripts/check-vercel-build.js --no-build # check api/ only (no build)
node scripts/check-vercel-build.js --source  # check api-src/ only
```

The script reports 0-byte API files and missing expected routes (including bakery endpoints: `orders/update-status`, `stripe/refund`, `analytics/export`, `settings/business-hours`).

**Inspect a deployed build:**

```bash
vercel list                    # list recent deployments (use production URL or ID)
vercel inspect <url-or-id>     # deployment details
vercel inspect <url-or-id> --logs   # build logs (errors, missing files, etc.)
```

Use `--logs` to see if the remote build reported any empty or missing files.

**Compare Vercel deployments to app (missing features):**

Compares **deployed** API (from Vercel) to the routes the app expects (core + bakery). Requires a [Vercel API token](https://vercel.com/account/tokens). By default the script **scans all recent builds** (production and preview).

```bash
VERCEL_TOKEN=your_token node scripts/check-vercel-deployment-vs-app.js
# Scans up to 20 recent deployments; table + detail for any missing routes

VERCEL_TOKEN=your_token node scripts/check-vercel-deployment-vs-app.js --limit 50
# Scan up to 50 recent builds

VERCEL_TOKEN=your_token node scripts/check-vercel-deployment-vs-app.js --latest
# Only the single latest production deployment (legacy behavior)

VERCEL_TOKEN=your_token node scripts/check-vercel-deployment-vs-app.js --latest --preview
# Only the single latest preview deployment
```

Reports: per-build API route count, missing count, bakery status; then a detail section for every build that is missing routes, and a final summary.

## 5. Post-deploy

- Point the iOS app at your Vercel URL (e.g. `https://your-project.vercel.app`).
- Confirm env vars are set for Production.
- Run a quick smoke test: health, login, products, orders.

## 6. Troubleshooting

### rsync: `mmap: Operation timed out` / Node: `ETIMEDOUT`

- **Use the shell script** – it tries rsync with `--no-mmap`, then a `cp` loop, then the Node script:
  ```bash
  ./scripts/sync-api-for-vercel.sh
  ```
- **Node script** now retries each file 3 times (stream copy) and falls back to chunked read/write if needed. Run from **Terminal.app** (not Cursor) if you still see timeouts.
- See **docs/TIMEOUT_FIXES.md** for more options.

### Vercel: `ETIMEDOUT: connection timed out, read`

1. **Update Vercel CLI** (newer versions often fix connection issues):
   ```bash
   npm i -g vercel@latest
   ```

2. **Check network**: Try from a different Wi‑Fi or disable VPN/proxy temporarily.

3. **Deploy in two steps** (sync first, then deploy):
   ```bash
   node scripts/sync-api-for-vercel.js
   vercel --prod
   ```

4. If it still fails, deploy from the [Vercel dashboard](https://vercel.com) by connecting your repo and deploying the branch (no CLI needed).

## Staging / preview environment (recommended)

For safe QA before production:

1. **Vercel**: Create a second Vercel project (or use **Preview** deployments per branch) pointing at the same repo.
2. **Neon**: Create a **branch** or separate database for staging; set `POSTGRES_URL` / `DATABASE_URL` on the staging Vercel project to that branch’s connection string (never share prod DB with experimental builds).
3. **Stripe**: Use **test mode** keys (`sk_test_…`, publishable test key) on staging; keep **live** keys only on production.
4. **iOS / macOS app**: Add a **staging** `AppConstants.vercelBaseURLString` (or build configuration / `.xcconfig`) that targets the preview URL, and run TestFlight builds against staging before promoting.

**After pulling latest backend changes**, run `scripts/add-order-idempotency.sql` on **each** database (staging + prod) if you use order idempotency.
