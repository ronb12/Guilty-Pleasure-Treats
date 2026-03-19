#!/usr/bin/env bash
# Git CLI only: update main from GitHub (ronb12/Guilty-Pleasure-Treats)
# Run this in your terminal: ./scripts/git-update-main.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> safe.directory (in case Git refuses this path)"
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

echo ">>> remote"
git remote -v

echo ">>> branch"
git branch -a

echo ">>> status"
git status

echo ">>> checkout main"
git checkout main

echo ">>> pull origin main"
git pull origin main

echo ">>> done"
git status
