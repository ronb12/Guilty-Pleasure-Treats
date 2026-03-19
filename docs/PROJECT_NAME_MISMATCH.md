# Project name mismatch check

Different names are used in different places. Only one must match GitHub.

## Name variants

| Where | Name | Notes |
|-------|------|--------|
| **GitHub repo (canonical)** | `Guilty-Pleasure-Treats` | URL: `https://github.com/ronb12/Guilty-Pleasure-Treats` — **hyphens**, no spaces. This is what your remote must point to. |
| **Local folder (this workspace)** | `GuiltyPleasureTreats` | No hyphens, no spaces. Folder name does **not** need to match the GitHub repo name. |
| **Other copies (docs)** | `Guilty Pleasure Treats` | With spaces (e.g. Desktop). Can cause issues in terminals; avoid for `cd` and scripts. |
| **Xcode / app** | `Guilty Pleasure Treats` | Display name; folder under project root has a space. |

## What actually matters for Git

- **Remote URL** in `.git/config` must point to the correct GitHub repo:
  - Correct: `https://github.com/ronb12/Guilty-Pleasure-Treats` or `https://github.com/ronb12/Guilty-Pleasure-Treats.git`
  - Wrong: different repo name (e.g. `GuiltyPleasureTreats` on GitHub would be a different repo), or wrong user/org.

## How to check for a mismatch

In a terminal where Git works:

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
git remote -v
```

You should see something like:

```
origin  https://github.com/ronb12/Guilty-Pleasure-Treats.git (fetch)
origin  https://github.com/ronb12/Guilty-Pleasure-Treats.git (push)
```

If the URL shows a different repo name (e.g. `GuiltyPleasureTreats` instead of `Guilty-Pleasure-Treats`) or a different user, fix it:

```bash
git remote set-url origin https://github.com/ronb12/Guilty-Pleasure-Treats.git
git remote -v
```

## Summary

- **No mismatch** if your `origin` URL is `.../ronb12/Guilty-Pleasure-Treats` (with hyphens). Local folder name can be `GuiltyPleasureTreats` or anything.
- **Mismatch** only if `origin` points to a different repo (wrong name or wrong account). Use `git remote set-url origin ...` to fix.
