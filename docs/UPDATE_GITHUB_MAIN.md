# Always Update GitHub Main After Updates

After making changes to the project (code, config, docs, or schema), **push to GitHub `main`** so the remote stays in sync and others (or CI/CD) have the latest.

## Checklist

- [ ] Commit your changes locally.
- [ ] Push to `origin main` (or your default remote/branch).

## Commands

```bash
# From project root
git add -A
git status   # review what will be committed
git commit -m "Your descriptive message"
git push origin main
```

If your default branch is `main` and you track it:

```bash
git add -A
git commit -m "Your descriptive message"
git push
```

## When to do it

- After feature work, bug fixes, or refactors.
- After updating API, app, or scripts.
- After running or changing Neon schema/migrations (and committing any schema file changes).
- After doc or runbook updates.

## Note

If you use a different workflow (e.g. PRs from a branch), merge to `main` and push so `main` on GitHub is always up to date.
