#!/usr/bin/env bash
# Replicate the last-success update: same steps that get main updated from GitHub.
# Use this when you want the exact sequence that works (including /tmp if needed).
#
# Success path (pick one):
#   A) From project folder (if .git is fast): ./scripts/replicate-success-update.sh
#   B) If you get timeouts: copy to /tmp first, then run this script there (see below).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ">>> Replicating success update at: $REPO_ROOT"
echo ""

# 1. safe.directory (so Git accepts this path)
echo ">>> [1/4] safe.directory"
git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true

# 2. Ensure we're on main
echo ">>> [2/4] checkout main"
git checkout main

# 3. Pull from GitHub (this is the "update")
echo ">>> [3/4] pull origin main"
git pull origin main

# 4. Confirm
echo ">>> [4/4] status"
git status
echo ""
echo "Done. Main is updated from GitHub."
