#!/bin/bash
# Sync api-src into api for Vercel. Keeps api/lib intact.
# 1. Try rsync with --no-mmap (avoids mmap timeout)
# 2. If that fails, use cp loop (no rsync, no mmap)
# 3. If cp fails, fall back to Node script (stream + chunked fallback)
set -e
cd "$(dirname "$0")/.."

sync_with_rsync() {
  rsync -a --exclude='lib' --no-mmap api-src/ api/ 2>/dev/null
}

sync_with_cp() {
  for f in api-src/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = "lib" ] && continue
    dest="api/$name"
    [ -d "$dest" ] && rm -rf "$dest"
    [ -f "$dest" ] && rm -f "$dest"
    cp -R "$f" api/
  done
}

if sync_with_rsync; then
  echo "Synced api-src -> api for Vercel (rsync)."
  exit 0
fi

set +e
sync_with_cp 2>/dev/null
cp_result=$?
set -e
if [ "$cp_result" -eq 0 ]; then
  echo "Synced api-src -> api for Vercel (cp)."
  exit 0
fi

echo "Trying Node sync (stream + chunked fallback)..." >&2
exec node scripts/sync-api-for-vercel.js
