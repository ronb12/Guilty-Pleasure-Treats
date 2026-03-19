#!/usr/bin/env bash
# Diagnose what on your computer might be causing "Operation timed out" and "fcopyfile failed".
# Run in Terminal.app: cd /Users/ronellbradley/Projects/GuiltyPleasureTreats && ./scripts/diagnose-timeout-causes.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "=============================================="
echo "Timeout causes diagnostic — $REPO_ROOT"
echo "=============================================="
echo ""

# 1. Where is the project?
echo ">>> 1. Path and filesystem"
echo "    Path: $REPO_ROOT"
if command -v df >/dev/null 2>&1; then
  FS=$(df "$REPO_ROOT" 2>/dev/null | tail -1)
  echo "    df: $FS"
  if echo "$FS" | grep -qi "clouddocs\|icloud\|network"; then
    echo "    ** POSSIBLE CAUSE: Project may be on iCloud or network volume. Move to a local folder (e.g. ~/LocalProjects) or ensure files are downloaded."
  fi
fi
echo ""

# 2. iCloud Desktop & Documents
echo ">>> 2. iCloud Desktop & Documents"
if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
  if [[ "$REPO_ROOT" == *"Desktop"* ]] || [[ "$REPO_ROOT" == *"Documents"* ]] || [[ "$REPO_ROOT" == *"Projects"* ]]; then
    echo "    Projects/Desktop/Documents can be synced by iCloud. If 'Desktop & Documents' is on in iCloud, this path may be in the cloud."
    echo "    ** FIX: In Finder, right-click project folder → Download Now. Or move project to a folder not in iCloud (e.g. ~/LocalProjects)."
  else
    echo "    Project path does not look like a typical iCloud path."
  fi
else
  echo "    iCloud Drive Mobile Documents not found (or path not standard)."
fi
echo ""

# 3. Cursor sandbox config
echo ">>> 3. Cursor sandbox (can throttle file I/O in Cursor)"
for f in "$HOME/.cursor/sandbox.json" "$REPO_ROOT/.cursor/sandbox.json"; do
  if [ -f "$f" ]; then
    echo "    Found: $f"
    cat "$f" 2>/dev/null | head -20 || echo "    (could not read)"
  fi
done
if [ ! -f "$HOME/.cursor/sandbox.json" ] && [ ! -f "$REPO_ROOT/.cursor/sandbox.json" ]; then
  echo "    No .cursor/sandbox.json found. Cursor may still use internal sandbox for agent/terminal."
fi
echo "    ** FIX: Run Git and large copies from Terminal.app, not Cursor."
echo ""

# 4. Can we read .git?
echo ">>> 4. Test read of .git/HEAD"
if cat "$REPO_ROOT/.git/HEAD" 2>/dev/null; then
  echo ""
  echo "    OK: .git is readable here (this terminal)."
else
  echo "    FAIL or TIMEOUT: .git not readable in this shell too. Likely disk/iCloud/network or permission."
fi
echo ""

# 5. Full Disk Access hint
echo ">>> 5. Full Disk Access"
echo "    If Terminal or Cursor is sandboxed, add it in: System Settings → Privacy & Security → Full Disk Access"
echo ""

# 6. Summary
echo "=============================================="
echo "Summary: Run Git and file copies from Terminal.app. If project is on iCloud or network drive, copy repo to /tmp or ~/LocalProjects and work there."
echo "=============================================="
