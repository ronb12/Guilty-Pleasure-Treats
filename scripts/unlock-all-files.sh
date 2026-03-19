#!/usr/bin/env bash
# Unlock all files in the project (remove locked flag, ensure write, clear quarantine).
# Run from project root: ./scripts/unlock-all-files.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ">>> Removing locked flag (chflags nouchg)..."
chflags -R nouchg . 2>/dev/null || true

echo ">>> Ensuring write permission (chmod u+w)..."
chmod -R u+w . 2>/dev/null || true

echo ">>> Clearing quarantine/extended attributes (xattr -cr)..."
xattr -cr . 2>/dev/null || true

echo "Done. All files unlocked."
