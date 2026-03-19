# Last success update — what to run

This doc records the **exact sequence that produces a successful update** of `main` from GitHub. Use it to replicate that result.

## Success path (when .git is readable)

Run from the project root (e.g. Terminal.app):

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats

git config --global --add safe.directory "$(pwd)"
git checkout main
git pull origin main
git status
```

**Or use the script:**

```bash
./scripts/replicate-success-update.sh
```

## Success path when you get "Operation timed out" on .git

If the project is on a network or synced folder and `.git` times out:

1. Copy the repo to a local folder (e.g. `/tmp`).
2. Run the fix script, then the update, in that copy.

**One script does both:**

```bash
cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
./scripts/replicate-success-update-from-tmp.sh
```

That script:

- Copies the repo to `/tmp/GuiltyPleasureTreats`
- Runs `fix-all-git-causes.sh` there
- Runs `checkout main` and `pull origin main` there
- Tells you how to copy the updated repo back to `Projects` if you want

## Summary

| Situation              | Command |
|------------------------|--------|
| .git works in project  | `./scripts/replicate-success-update.sh` |
| .git times out         | `./scripts/replicate-success-update-from-tmp.sh` |

The **core update** is always: `git checkout main` then `git pull origin main`.
