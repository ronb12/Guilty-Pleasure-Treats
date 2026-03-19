#!/usr/bin/env bash
# Replicate the last-success update when the project folder has .git timeouts.
# This copies the repo to /tmp (fast local disk), fixes and updates there, then you can copy back.
#
# Run from the project folder:
#   cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
#   ./scripts/replicate-success-update-from-tmp.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_REPO="/tmp/GuiltyPleasureTreats"

echo ">>> Copying repo to /tmp (avoids .git timeouts on network/synced folders)..."
rm -rf "$TMP_REPO"
cp -R "$REPO_ROOT" "$TMP_REPO"
echo ">>> Copied to $TMP_REPO"
echo ""

echo ">>> Fixing repo and updating in /tmp..."
"$TMP_REPO/scripts/fix-all-git-causes.sh" || true
echo ""

echo ">>> Replicating success update (checkout main, pull)..."
cd "$TMP_REPO"
git config --global --add safe.directory "$TMP_REPO" 2>/dev/null || true
git checkout main
git pull origin main
git status
echo ""

echo ">>> Success. Updated copy is at: $TMP_REPO"
echo ">>> To use it from Projects again, copy back:"
echo "    rsync -a --exclude='.git' \"$TMP_REPO/\" \"$REPO_ROOT/\"   # only working tree"
echo "    cp -R \"$TMP_REPO/.git\" \"$REPO_ROOT/.git\"               # or replace .git (backup first)"
echo "Or continue working from: $TMP_REPO"
