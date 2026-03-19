#!/usr/bin/env bash
# Make this folder a git repository (fresh clone from GitHub main).
# Use when .git is missing, corrupted, or unreadable. Run in Terminal.app:
#   cd /Users/ronellbradley/Projects/GuiltyPleasureTreats
#   ./scripts/make-git-repository.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="https://github.com/ronb12/Guilty-Pleasure-Treats.git"

cd "$REPO_ROOT"

echo ">>> Backing up existing .git (if present)..."
if [ -d .git ]; then
  rm -rf .git.bak 2>/dev/null || true
  mv .git .git.bak
  echo "    Moved .git to .git.bak"
fi

echo ">>> Initializing new git repository..."
git init

echo ">>> Adding remote origin..."
git remote add origin "$REMOTE"

echo ">>> Fetching from GitHub..."
git fetch origin main

echo ">>> Checking out main (overwriting local files to match GitHub)..."
git checkout -f -b main origin/main
git branch --set-upstream-to=origin/main main

echo ">>> Adding safe.directory..."
git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true

echo ""
echo "Done. This folder is now a git repository on main, tracking origin/main."
git status
