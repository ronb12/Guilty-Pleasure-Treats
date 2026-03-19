# Last successful Vercel deployment — replicate

Same method as the working deploy: **sync api-src → api**, then **deploy to production**.

## Option A: One script (recommended)

Run in **Terminal.app** (CLI deploy times out from Cursor):

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
./scripts/replicate-vercel-deploy.sh
```

## Option B: Two commands

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
bash scripts/sync-api-for-vercel.sh
vercel --prod
```

## Option C: npm

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
npm run deploy
```

(`npm run deploy` runs `vercel:sync` then `vercel --prod`.)

## Option D: Git push (auto-deploy)

If the repo is connected in the [Vercel dashboard](https://vercel.com), push to `main`:

```bash
git add .
git commit -m "Your message"
git push origin main
```

Vercel will build and run **buildCommand** (`bash scripts/sync-api-for-vercel.sh`) so `api/` is populated from `api-src/` on their servers. No local CLI needed.

---

**Summary:** Sync then `vercel --prod` (or push to main for Git deploy). Use Terminal; Cursor’s environment often hits `ETIMEDOUT` on the deploy step.

---

## If you see "A server error has occurred" / FUNCTION_INVOCATION_FAILED in the app

1. **Set Vercel env vars** (Dashboard → Project → Settings → Environment Variables):
   - **DATABASE_URL** or **POSTGRES_URL** — Neon Postgres connection string (required for products, orders, etc.).
   - **JWT_SECRET** or **AUTH_SECRET** — secret for auth (required for protected routes).

2. **Redeploy** after adding env vars so the new values are used.

3. **Health check:** Open `https://your-project.vercel.app/api/health` in a browser; it should return `{"ok":true,"status":"healthy"}`. If that works but the app still errors, ensure the `products` table exists in Neon (run your schema migrations).
