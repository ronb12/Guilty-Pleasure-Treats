# Fixing timeout issues (sync, copy, Vercel deploy)

Based on common causes and fixes found online, here’s how to address the timeouts you’re seeing.

**Script updates (already in this project):** The sync script now (1) tries **rsync --no-mmap**, then (2) a **cp** loop, then (3) **Node** with **stream copy + 3 retries per file + chunked read/write fallback**. Run `./scripts/sync-api-for-vercel.sh` or `node scripts/sync-api-for-vercel.js` from **Terminal.app** for best results.

---

## 1. rsync: “mmap: Operation timed out”

### What’s going on

- **Local copy:** rsync can use `mmap()` for file I/O. On some macOS setups (e.g. certain disks, APFS, or sandboxed environments like Cursor’s), that path can hit a timeout.
- **Network rsync:** “Operation timed out” is often a **network/firewall** issue (e.g. port 873 blocked, wrong network). Your case is **local** (api-src → api on the same machine), so the fixes below focus on local copy.

### Fixes to try

**A. Disable mmap (if your rsync supports it)**

```bash
rsync -a --exclude='lib' --no-mmap api-src/ api/
```

If `--no-mmap` is not recognized, your system rsync may be old; try Homebrew’s:

```bash
brew install rsync
# then use the same command; Homebrew’s rsync is often newer and supports more options
```

**B. Use the Node sync script (no rsync)**

The project’s Node script uses stream-based copy (read stream → write stream), so it doesn’t use rsync or mmap:

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
node scripts/sync-api-for-vercel.js
```

If that still hits **ETIMEDOUT** (see below), try **C** or **D**.

**C. Copy with `cp` in a loop (bypass rsync and mmap)**

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
for f in api-src/*; do
  name=$(basename "$f")
  [ "$name" = "lib" ] && continue
  rm -rf "api/$name" 2>/dev/null
  cp -R "$f" api/
done
echo "Sync done."
```

**D. Run from a normal Terminal (not inside Cursor/sandbox)**

Timeouts can be caused by the environment (e.g. Cursor’s runner or sandbox). Run the same **rsync** or **Node** sync command from **Terminal.app** or iTerm on your Mac. Often the same command works there.

**E. Check disk and path**

- Make sure the project is on a **local disk** (not a network/SMB/AFP volume). Timeouts are common on network shares.
- Avoid paths with special characters or very long path lengths.

---

## 2. Node.js: “ETIMEDOUT” on `fs.copyFile` / file copy

### What’s going on

- **ETIMEDOUT** on file operations usually means the OS or environment is killing the operation after a short time.
- Common when: copying to/from **network drives**, or running inside **sandboxed/restricted environments** (e.g. Cursor agent, CI, containers) that impose strict I/O limits.

### Fixes to try

**A. Run the script outside the sandbox**

Run `node scripts/sync-api-for-vercel.js` from **Terminal.app** (or iTerm) on your Mac, not from inside Cursor. Same for any script that copies many files.

**B. Ensure the project is on a local disk**

If the project lives on a network share (SMB, NFS, etc.), copy it to a **local folder** (e.g. `~/Projects/GuiltyPleasureTreats`) and run the sync there.

**C. Use stream-based copy (already in the script)**

The current sync script uses **streams** (createReadStream → pipe → createWriteStream) instead of `copyFileSync`, which avoids the `copyfile`/fcopyfile path that can timeout on some systems. If you still see ETIMEDOUT:

- Run the script from a normal Terminal (see **A**).
- If you’re on Node 14, upgrade to at least 14.18.2 (improved behavior on NFS/copyfile).

**D. Add a longer “timeout” by retrying**

You can wrap the copy in a retry loop (e.g. retry each file up to 2–3 times with a short delay). That doesn’t fix the root cause but can help on flaky I/O.

---

## 3. Vercel CLI: “ETIMEDOUT: connection timed out, read”

### What’s going on

This is a **network** error: the CLI can’t complete the request to Vercel’s servers in time. Common causes: slow or unstable internet, proxy/firewall, or an outdated CLI.

### Fixes to try (from Vercel/Next.js discussions)

**A. Update Vercel CLI**

Newer versions often fix timeout and connection handling:

```bash
npm i -g vercel@latest
vercel --prod
```

**B. Check network**

- Try another network (e.g. phone hotspot) to see if the problem is network-specific.
- If you use a **proxy or VPN**, try disabling it temporarily, or configure the CLI/proxy for `vercel.com` and `*.vercel.app`.

**C. Deploy from the Vercel dashboard**

If the CLI keeps timing out:

1. Connect your repo in the [Vercel dashboard](https://vercel.com).
2. Deploy the branch from the UI (e.g. “Deploy” from the project page).

That uses Vercel’s own infrastructure to clone and build, so it doesn’t depend on your machine’s outbound connection for the full upload.

**D. Run sync and deploy in two steps**

Sync first, then deploy, so a sync retry doesn’t re-run the whole deploy:

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
rsync -a --exclude='lib' api-src/ api/   # or node scripts/sync-api-for-vercel.js
vercel --prod
```

---

## 4. Quick reference

| Symptom | First thing to try |
|--------|---------------------|
| rsync mmap timeout | `rsync -a --exclude='lib' --no-mmap api-src/ api/` or run from Terminal, or use `cp` loop (C above). |
| Node copyFile/ETIMEDOUT | Run `node scripts/sync-api-for-vercel.js` from Terminal; ensure project is on local disk. |
| Vercel ETIMEDOUT | `npm i -g vercel@latest`, then `vercel --prod`; or deploy from Vercel dashboard. |

**Recommended order for your project**

1. Run sync and deploy from **Terminal.app** (not Cursor):  
   `cd /Users/ronellbradley/Projects/GuiltyPleasureTreats` then rsync (or Node script) then `vercel --prod`.
2. If rsync still times out, use **--no-mmap** or the **cp loop** (section 1C).
3. If Vercel still times out, **update the CLI** and try another network or **deploy from the dashboard**.
