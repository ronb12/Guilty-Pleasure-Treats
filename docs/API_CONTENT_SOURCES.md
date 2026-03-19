# Where the API file content lives (search results)

Searched the project and git to find where the non-empty API handler content comes from.

---

## 1. **Projects/GuiltyPleasureTreats (this copy) — HAS the content**

- **api-src/** here has the full handler content (verified: health.js 476 bytes, orders.js 5408, auth/login.js 4398, etc.).
- **api/** was fixed by creating **symlinks** from each `api/` file to the matching file in `api-src/`. So when you read `api/health.js` you get the content of `api-src/health.js`.
- **api/lib/** was left as-is (real files: db, auth, cors, apns, neonAuth).

So in this project, the “missing” content is **not** missing: it lives in **api-src/**, and **api/** points to it via symlinks.

---

## 2. **Home copy (~/GuiltyPleasureTreats) — api-src is EMPTY**

- At `~/GuiltyPleasureTreats`, **api-src/health.js** is **0 bytes**.
- So that copy does **not** have the handler content. If you use that copy, restore api-src from this (Projects) copy or from git (see below).

---

## 3. **Git (~/GuiltyPleasureTreats repo)**

- **Commit 72e57c1** (“Add Vercel API: serverless endpoints for health, products, orders”) has **non-empty** versions of:
  - `api/health.js` (290 bytes — older version)
  - `api/index.js`
  - `api/orders.js`
  - `api/products.js`
- **HEAD** tracks only a **subset** of api files (e.g. api/auth/login.js, api/auth/signup.js, api/[[...path]].js, api/lib/*, etc.). Some of those are **empty** in HEAD (e.g. api/auth/me.js = 0 bytes in HEAD).
- So git has **partial** content: use 72e57c1 for the four root files; for the rest, git never had the full set of handlers (contact, customers, analytics, stripe, etc.).

---

## 4. **Other locations**

- **Desktop** copy (`~/Desktop/Guilty Pleasure Treats`) was not readable in the check (path/permission).
- **External drive** (My Passport for Mac) was not checked; you can look there for an older backup of `api/` or `api-src/` if needed.
- Another project at `~/Projects/Faith Journal/token-server/api/health.js` has a health.js but it’s a **different** app, not Guilty Pleasure Treats.

---

## 5. **Vercel builds (deployed content)**

Vercel stores the **source and build output** of each deployment. You can recover API file content from a **successful deployment** in two ways.

### A. Inspect in the Vercel dashboard

1. Open [vercel.com](https://vercel.com) → your project → **Deployments**.
2. Open a **successful** deployment (e.g. production).
3. Use the **Source** (or **Files**) tab to browse the deployed files. You can view (and copy) the contents of `api/*.js` there.

So **Vercel builds are another source** for the content: whatever was in the build that succeeded is visible in that deployment’s source.

### B. Get file content via Vercel REST API

You need a **Vercel API token** (Account → Settings → Tokens) and the **deployment ID** (from the deployment URL or from “List deployments”).

- **List deployment files:**  
  `GET https://api.vercel.com/v6/deployments/{deploymentId}/files`  
  (Auth: `Authorization: Bearer <token>`)
- **Get one file’s content (base64):**  
  `GET https://api.vercel.com/v8/deployments/{deploymentId}/files/{fileId}`  
  (For Git deployments you can use query `path=api/health.js` instead of `fileId` where supported.)

A script that uses these endpoints to download `api/*.js` from the latest deployment into your local `api/` folder is in **scripts/restore-api-from-vercel-deployment.js** (see below). Run it with:

```bash
VERCEL_TOKEN=your_token node scripts/restore-api-from-vercel-deployment.js
```

So: **yes, check Vercel builds for the content** — use the dashboard Source tab or the REST API to pull the same files that were deployed.

---

## 6. **What to do**

**If you work in Projects/GuiltyPleasureTreats (this copy):**  
Nothing else needed. api/ is already backed by api-src/ via symlinks. Deploy as usual.

**If you work in ~/GuiltyPleasureTreats and api-src is empty:**  
Restore api-src from this copy:

```bash
rsync -a --exclude='lib' /Users/ronellbradley/Projects/GuiltyPleasureTreats/api-src/ /Users/ronellbradley/GuiltyPleasureTreats/api-src/
```

**If you want real files in api/ instead of symlinks (e.g. for a tool that doesn’t follow symlinks):**  
Run the sync script from **Terminal.app** on your Mac (from this project folder):

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
./scripts/restore-api-from-api-src.sh
```

That copies api-src into api/ as real files. If you already have symlinks, remove them first or run the script and it will overwrite with real content from api-src.

**To restore a few files from git (e.g. older versions):**

```bash
cd ~/GuiltyPleasureTreats
git show 72e57c1:api/health.js > api/health.js
# repeat for api/index.js, api/orders.js, api/products.js if desired
```

---

## Summary

| Location | api/ or api-src content |
|----------|--------------------------|
| **Projects/GuiltyPleasureTreats** | api-src has full content; api/ uses symlinks → api-src (content is there). |
| **~/GuiltyPleasureTreats** | api-src is empty; restore from Projects or git. |
| **Git 72e57c1** | 4 root api files (health, index, orders, products) have content. |
| **Git HEAD** | Subset of api files; some empty. |
| **Vercel builds** | Deployed source is in the deployment’s Source/Files in the dashboard; can also fetch via REST API (list files, get file content). |

The “missing” content for the handlers is in **api-src** in **Projects/GuiltyPleasureTreats** and (if you’ve deployed) in **Vercel build source**; **api/** in Projects is already fixed by symlinks to api-src.
