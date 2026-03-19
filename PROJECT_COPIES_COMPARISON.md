# Guilty Pleasure Treats — project copies comparison

Search covered: your Mac user folder and external drive **My Passport for Mac**.

---

## 1. Where the project exists

| Location | Path | Swift files | Last activity |
|----------|------|-------------|----------------|
| **Desktop (this copy)** | `~/Desktop/Guilty Pleasure Treats` | 87 | Admin / app edits (Mar 16–17) |
| **Home — latest** | `~/GuiltyPleasureTreats` | **93** | Splash, RootView, SampleData (Mar 18) |
| **External backup** | `My Passport for Mac/Moved_From_Mac_20260315/Desktop_backup/Guilty Pleasure Treats` | 57 | Mar 15 backup; older |

---

## 2. Which copy has the most features (latest)

**The copy with the most features is: `~/GuiltyPleasureTreats` (home directory).**

- **6 extra Swift files** that Desktop does not have:
  - `Models/ProductCategory.swift`
  - `Utilities/Extensions/View+Navigation.swift`
  - `Utilities/PlatformImage.swift`
  - `Views/Admin/AdminOrderTrackingSheet.swift`
  - `Views/Components/TrackingInfoView.swift`
  - `Views/ContentView.swift`
- **Same 87 shared files** exist on both Desktop and Home, but **content differs** in many of them (70+ files). Home has the newer splash (live-app style), RootView timing, and other recent changes.
- **Git repo** is in `~/GuiltyPleasureTreats` (branch `main`); some of the extra files are still untracked there.
- **External drive** is an older backup (Mar 15) with fewer files; use only for recovery, not as “latest.”

---

## 3. Recommendation

- **Use `~/GuiltyPleasureTreats` as your single source of truth** (most features, latest edits, git history).
- **Sync that copy to Desktop** if you want to keep opening the project from `~/Desktop/Guilty Pleasure Treats` (e.g. run the script below once).
- **Back up** important work from Desktop into the Home copy (or into git) before overwriting Desktop with the sync.

---

## 4. Sync script (Home → Desktop)

From the **Desktop** project folder, you can run:

```bash
./scripts/sync_from_latest.sh
```

That script copies the latest files from `~/GuiltyPleasureTreats` into `~/Desktop/Guilty Pleasure Treats` so both locations match the “most features” copy.  
See `scripts/sync_from_latest.sh` for what it copies and optional backup.
