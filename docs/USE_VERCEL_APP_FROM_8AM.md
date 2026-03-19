# Use the app from Vercel from 8:00 AM this morning

To make production use the deployment that was live **at 8:00 AM this morning**, use one of these methods.

---

## Option A: Vercel Dashboard (recommended)

1. Open **[Vercel Dashboard](https://vercel.com)** → your team → **guilty-pleasure-treats** (or your project name).
2. Go to the **Deployments** tab.
3. Find the deployment whose **Created** time is **around 8:00 AM today** (use your local timezone).
4. Click the **⋮** (three dots) on that deployment.
5. Click **"Instant Rollback"** (or **"Promote to Production"** if it’s currently a preview).
6. Confirm. Production will then serve that deployment.

---

## Option B: List deployments from CLI, then rollback

**1. List recent deployments with timestamps**

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
VERCEL_TOKEN=your_token node scripts/list-vercel-deployments.js
```

Or show more entries:

```bash
VERCEL_TOKEN=your_token node scripts/list-vercel-deployments.js --limit 30
```

**2. Find the deployment from ~8:00 AM**

- Check the **Created (UTC)** column (convert to your local time if needed), or
- Use the deployment **URL** (e.g. `guilty-pleasure-treats-abc123.vercel.app`) for the build from around 8 AM.

**3. Rollback production to that deployment**

```bash
vercel rollback <deployment-url-or-uid>
```

Examples:

```bash
vercel rollback guilty-pleasure-treats-abc123xyz.vercel.app
# or
vercel rollback dpl_xxxxxxxxxxxx
```

Production will then point to that deployment. Your app (e.g. **guilty-pleasure-treats.vercel.app**) will serve the API from 8 AM.

---

## Get a Vercel token

1. Go to [vercel.com/account/tokens](https://vercel.com/account/tokens).
2. Create a token with the right scope (e.g. Full Account or the project).
3. Use it: `export VERCEL_TOKEN=your_token` or `VERCEL_TOKEN=your_token` in the commands above.

---

## Notes

- **Rollback** moves the production alias to the deployment you choose; it doesn’t create a new build.
- After a rollback, new Git pushes may not auto-assign to production until you run **Promote** on a deployment again (see [Vercel docs](https://vercel.com/docs/deployments/rollback-production-deployment)).
- The **iOS app** points at your Vercel production URL (e.g. `https://guilty-pleasure-treats.vercel.app`). Once production is rolled back to the 8 AM deployment, the app will use that API without any app update.
