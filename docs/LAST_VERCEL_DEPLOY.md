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
