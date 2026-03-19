#!/usr/bin/env bash
# Fix: fatal: could not set 'core.repositoryformatversion' to '0'
# This happens when Git can't write to .git/config (timeout, permission, or synced volume).
# Run in Terminal.app: cd /Users/ronellbradley/Projects/GuiltyPleasureTreats && ./scripts/fix-repositoryformatversion.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="https://github.com/ronb12/Guilty-Pleasure-Treats.git"
MAIN_COMMIT="972c7c5bfd8a0ab8bfc9c70d1a0edcf23958a674"

cd "$REPO_ROOT"

# Use temp files and copy into .git to avoid direct writes (can timeout on synced/network volumes)
TMPD="/tmp/git-fix-$$"
mkdir -p "$TMPD"
cleanup() { rm -rf "$TMPD"; }
trap cleanup EXIT

echo ">>> Ensuring .git exists..."
mkdir -p .git/refs/heads

echo ">>> Writing .git/config (via temp file to avoid timeout)..."
cat > "$TMPD/config" << EOF
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	url = $REMOTE
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "main"]
	remote = origin
	merge = refs/heads/main
EOF
if ! cp "$TMPD/config" .git/config 2>/dev/null; then
  echo "    ERROR: Could not copy config to .git (e.g. Operation timed out)."
  echo "    Move project to a local folder and try again:"
  echo "      cp -R \"$REPO_ROOT\" /tmp/GuiltyPleasureTreats"
  echo "      /tmp/GuiltyPleasureTreats/scripts/fix-repositoryformatversion.sh"
  exit 1
fi

echo ">>> Writing .git/HEAD..."
printf 'ref: refs/heads/main\n' > "$TMPD/HEAD"
cp "$TMPD/HEAD" .git/HEAD

echo ">>> Writing refs/heads/main..."
printf '%s\n' "$MAIN_COMMIT" > "$TMPD/main"
mkdir -p .git/refs/heads
cp "$TMPD/main" .git/refs/heads/main

echo ">>> Adding safe.directory..."
git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true

echo ">>> Verifying..."
git status
echo ""
echo "Fixed. You can now run: git pull origin main"
