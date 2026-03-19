#!/usr/bin/env bash
# Fix "fatal: not a git repository" when .git exists
# See: https://blog.openreplay.com/fix-fatal-not-a-git-repository
#      https://www.codingem.com/git-fix-fatal-not-a-git-repository/

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Repository root: $REPO_ROOT"
echo ""

# 1. Allow this directory as safe (fixes safe.directory refusal in some environments)
echo ">>> Adding safe.directory for this repo..."
git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true

# 2. Check and fix .git/HEAD if missing or corrupted
if [ -f .git/HEAD ]; then
  HEAD_CONTENT=$(cat .git/HEAD 2>/dev/null || echo "")
  if [ -z "$HEAD_CONTENT" ] || [ ! -e ".git/$HEAD_CONTENT" ] 2>/dev/null; then
    echo ">>> Fixing corrupted or invalid .git/HEAD..."
    echo "ref: refs/heads/main" > .git/HEAD
  else
    echo ">>> .git/HEAD looks OK: $HEAD_CONTENT"
  fi
else
  echo ">>> Creating missing .git/HEAD..."
  echo "ref: refs/heads/main" > .git/HEAD
fi

# 3. Ensure refs/heads/main exists if HEAD points to it
if [ ! -f .git/refs/heads/main ] && [ -f .git/refs/heads/master ]; then
  echo ">>> Creating refs/heads/main from master..."
  mkdir -p .git/refs/heads
  cp .git/refs/heads/master .git/refs/heads/main 2>/dev/null || true
fi

# 4. Run git fsck to detect other corruption (non-fatal)
echo ">>> Running git fsck..."
git fsck --full 2>&1 || true

# 5. Verify
echo ""
echo ">>> Testing git..."
git status && echo "SUCCESS: Git repository is working." || echo "Run the commands below manually."
echo ""
echo "If still broken, try from a normal terminal (outside Cursor):"
echo "  cd $REPO_ROOT"
echo "  git status"
echo "Or re-clone: cd .. && rm -rf GuiltyPleasureTreats && git clone https://github.com/ronb12/Guilty-Pleasure-Treats.git GuiltyPleasureTreats"
