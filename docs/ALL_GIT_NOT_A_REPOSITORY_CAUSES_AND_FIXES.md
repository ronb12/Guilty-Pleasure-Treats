# All causes of "not a git repository" and how to fix them

This doc lists every common cause of the error and how they are fixed. One script fixes all of them in your repo.

## Error message

```text
fatal: not a git repository (or any of the parent directories): .git
```

## All causes and fixes

| # | Cause | Fix (in script) |
|---|--------|------------------|
| 1 | **safe.directory** – Git refuses to use the repo for security | `git config --global --add safe.directory /path/to/repo` |
| 2 | **Lock files** – `.git/index.lock` or other `*.lock` left behind | Remove all `*.lock` under `.git` |
| 3 | **Missing or corrupted .git/HEAD** – empty or invalid | Ensure `.git/HEAD` contains `ref: refs/heads/main` |
| 4 | **Missing refs/heads/main** – HEAD points to main but ref doesn’t exist | Create from `master` or `git fetch` + `update-ref` |
| 5 | **Wrong or missing remote** – project name mismatch or no origin | Set `origin` to `https://github.com/ronb12/Guilty-Pleasure-Treats.git` |
| 6 | **Repository corruption** – broken objects or refs | `git fsck --full` (and repair if it reports errors) |
| 7 | **Wrong directory** – not in repo root | `cd` to project root (e.g. `.../GuiltyPleasureTreats`) |
| 8 | **.git missing or deleted** | Re-clone or restore `.git` from backup |
| 9 | **Environment blocks reading .git** (e.g. Cursor sandbox) | Run Git in a normal terminal where `.git` is readable |

## One script that fixes causes 1–6

Run this **in a normal terminal** (Terminal.app, not necessarily inside Cursor):

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
./scripts/fix-all-git-causes.sh
```

The script:

1. Adds this repo to `safe.directory`
2. Removes any `.git/*.lock` files
3. Ensures `.git/HEAD` is valid (`ref: refs/heads/main`)
4. Ensures `refs/heads/main` exists
5. Sets or corrects `remote.origin.url` to `Guilty-Pleasure-Treats`
6. Runs `git fsck --full`
7. Runs `git status` to verify

## Causes 7–9 (manual)

- **Wrong directory:** Use `pwd` and `cd` to the repo root.
- **.git missing:** Re-clone:  
  `git clone https://github.com/ronb12/Guilty-Pleasure-Treats.git GuiltyPleasureTreats`
- **Environment blocks .git:** Use a terminal where `.git` can be read (e.g. Terminal.app). See `docs/WHY_NOT_A_GIT_REPOSITORY.md`.

## After running the script

If the script reports success:

```bash
git checkout main
git pull origin main
```

If it still fails, try re-cloning (see script output for exact commands).
