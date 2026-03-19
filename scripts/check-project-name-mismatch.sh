#!/usr/bin/env bash
# Check for project name mismatch: local folder vs Git remote.
# Run in your terminal: ./scripts/check-project-name-mismatch.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> Local folder name"
basename "$(pwd)"
echo ""

echo ">>> Git remote (origin)"
if ! git remote -v 2>/dev/null; then
  echo "Could not run 'git remote -v' (e.g. not a git repo or .git unreadable)."
  exit 1
fi
echo ""

EXPECTED="ronb12/Guilty-Pleasure-Treats"
URL=$(git config --get remote.origin.url 2>/dev/null || true)
if [[ -z "$URL" ]]; then
  echo ">>> No remote.origin.url found."
  exit 1
fi

if [[ "$URL" == *"$EXPECTED"* ]] || [[ "$URL" == *"Guilty-Pleasure-Treats"* ]]; then
  echo ">>> OK: Remote points to Guilty-Pleasure-Treats (expected). No project-name mismatch."
else
  echo ">>> MISMATCH: Remote URL does not contain expected repo name."
  echo "    Expected something like: .../ronb12/Guilty-Pleasure-Treats.git"
  echo "    Got: $URL"
  echo "    Fix with: git remote set-url origin https://github.com/ronb12/Guilty-Pleasure-Treats.git"
  exit 1
fi
