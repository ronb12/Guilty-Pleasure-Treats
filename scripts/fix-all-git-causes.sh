#!/usr/bin/env bash
# Fix ALL known causes of "fatal: not a git repository (or any of the parent directories): .git"
# Run in a normal terminal (e.g. Terminal.app): ./scripts/fix-all-git-causes.sh
#
# If you see "Operation timed out" on .git/HEAD: your project may be on a network
# or synced folder. Copy the repo to a local folder first, then run this script:
#   cp -R /Users/ronellbradley/Projects/GuiltyPleasureTreats /tmp/GuiltyPleasureTreats
#   /tmp/GuiltyPleasureTreats/scripts/fix-all-git-causes.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Repository root: $REPO_ROOT"
echo ""

# --- Cause 1: safe.directory (Git refuses to use repo) ---
echo ">>> [1/7] Adding safe.directory..."
git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true

# --- Cause 2: Lock files left behind ---
echo ">>> [2/7] Removing any .git lock files..."
find "$REPO_ROOT/.git" -name "*.lock" -type f 2>/dev/null | while read -r f; do
  echo "    Removing $f"
  rm -f "$f"
done
rm -f "$REPO_ROOT/.git/index.lock" "$REPO_ROOT/.git/HEAD.lock" 2>/dev/null || true

# --- Cause 3: Missing or corrupted .git/HEAD ---
# Use a temp file in /tmp to avoid timeouts when .git is on a slow/synced volume
echo ">>> [3/7] Ensuring .git/HEAD is valid..."
HEAD_TMP="/tmp/git-head-fix-$$"
printf 'ref: refs/heads/main\n' > "$HEAD_TMP"
if cp "$HEAD_TMP" "$REPO_ROOT/.git/HEAD" 2>/dev/null; then
  rm -f "$HEAD_TMP"
  echo "    .git/HEAD set to ref: refs/heads/main"
else
  rm -f "$HEAD_TMP"
  echo "    WARNING: Could not write .git/HEAD (e.g. Operation timed out)."
  echo ""
  echo "    Your project may be on a network drive or synced folder (e.g. iCloud)."
  echo "    Copy the repo to a local folder and run this script again:"
  echo ""
  echo "      cp -R \"$REPO_ROOT\" /tmp/GuiltyPleasureTreats"
  echo "      /tmp/GuiltyPleasureTreats/scripts/fix-all-git-causes.sh"
  echo ""
  echo "    Then copy back or work from /tmp/GuiltyPleasureTreats."
  echo "    Continuing with remaining steps..."
fi

# --- Cause 4: refs/heads/main missing (HEAD points to it) ---
echo ">>> [4/7] Ensuring refs/heads/main exists..."
mkdir -p "$REPO_ROOT/.git/refs/heads" 2>/dev/null || true
MAIN_REF="972c7c5bfd8a0ab8bfc9c70d1a0edcf23958a674"
if [ -f .git/refs/heads/main ]; then
  echo "    refs/heads/main exists"
elif [ -f .git/refs/heads/master ]; then
  if cp .git/refs/heads/master .git/refs/heads/main 2>/dev/null; then
    echo "    Created refs/heads/main from master"
  else
    printf '%s\n' "$MAIN_REF" > /tmp/git-main-ref-$$ && cp /tmp/git-main-ref-$$ .git/refs/heads/main 2>/dev/null && rm -f /tmp/git-main-ref-$$ && echo "    Created refs/heads/main from known main commit"
  fi
else
  printf '%s\n' "$MAIN_REF" > /tmp/git-main-ref-$$ 2>/dev/null
  if cp /tmp/git-main-ref-$$ .git/refs/heads/main 2>/dev/null; then
    rm -f /tmp/git-main-ref-$$
    echo "    Created refs/heads/main (from known main commit)"
  else
    rm -f /tmp/git-main-ref-$$
    echo "    Could not create refs/heads/main (timeout?). Try after copying repo to /tmp."
  fi
fi

# --- Cause 5: Wrong or missing remote (project name mismatch) ---
echo ">>> [5/7] Checking remote origin URL..."
EXPECTED_URL="https://github.com/ronb12/Guilty-Pleasure-Treats.git"
CURRENT_URL=$(git config --get remote.origin.url 2>/dev/null || true)
if [ -z "$CURRENT_URL" ]; then
  echo "    No origin; adding origin..."
  git remote add origin "$EXPECTED_URL"
elif [[ "$CURRENT_URL" != *"Guilty-Pleasure-Treats"* ]]; then
  echo "    Wrong remote URL; fixing..."
  git remote set-url origin "$EXPECTED_URL"
else
  echo "    Remote OK: $CURRENT_URL"
fi

# --- Cause 6: General repository corruption ---
echo ">>> [6/7] Running git fsck..."
git fsck --full 2>&1 || true

# --- Cause 7: Verify ---
echo ">>> [7/7] Verifying..."
if git status >/dev/null 2>&1; then
  echo ""
  echo "SUCCESS: Git repository is working."
  git status
  echo ""
  echo "You can now: git checkout main && git pull origin main"
else
  echo ""
  echo "Git still reports an error. Try re-clone:"
  echo "  cd $(dirname "$REPO_ROOT")"
  echo "  mv GuiltyPleasureTreats GuiltyPleasureTreats.bak"
  echo "  git clone https://github.com/ronb12/Guilty-Pleasure-Treats.git GuiltyPleasureTreats"
  exit 1
fi
