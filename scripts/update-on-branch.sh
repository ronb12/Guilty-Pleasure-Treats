#!/usr/bin/env bash
# Checkout copy-for-update branch and pull from main to see if it updates.
# Run in your terminal: ./scripts/update-on-branch.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> Current branch (before)"
git branch --show-current

echo ">>> Checkout branch copy-for-update"
git checkout copy-for-update

echo ">>> Pull origin main into this branch"
git pull origin main

echo ">>> Status after update"
git status
echo ">>> Done. Branch copy-for-update is now updated from main."
