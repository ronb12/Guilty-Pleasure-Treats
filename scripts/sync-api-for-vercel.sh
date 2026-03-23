#!/bin/bash
# Sync api-src into api for Vercel. Keeps api/lib intact.
# 1. Try rsync (optional --no-mmap on Linux when supported; omitted on macOS rsync)
# 2. If that fails, use cp loop (no rsync)
# 3. If cp fails, fall back to Node script (stream + chunked fallback)
set -e
cd "$(dirname "$0")/.."

# Vercel creates one Serverless Function per file under api/.
# The iOS app calls POST /api/stripe/create-payment-intent — that MUST exist as
# api/stripe/create-payment-intent.js in the deploy bundle. Relying only on
# api/[[...path]].js can yield Vercel’s HTML NOT_FOUND for that path.
# (Copies from api-src are full handlers, not stubs.)

sync_with_rsync() {
    if ! command -v rsync >/dev/null 2>&1; then
        return 1
    fi
    # macOS rsync has no --no-mmap; try it only when supported so Linux can avoid mmap timeouts.
    if rsync -a --exclude='lib' --no-mmap api-src/ api/ 2>/dev/null; then
        :
    else
        rsync -a --exclude='lib' api-src/ api/ >/dev/null 2>&1 || return 1
    fi
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
