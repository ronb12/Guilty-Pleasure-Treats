#!/bin/bash
# Restore api/ from api-src/ (fix empty files). Keeps api/lib unchanged.
# Run from project root in Terminal.app: ./scripts/restore-api-from-api-src.sh
set -e
cd "$(dirname "$0")/.."

if [ ! -d "api-src" ]; then
  echo "api-src not found. Run from project root." >&2
  exit 1
fi

mkdir -p api
count=0
err=0

while IFS= read -r -d '' src; do
  rel="${src#./api-src/}"
  dest="api/$rel"
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  if cp "$src" "$dest" 2>/dev/null; then
    count=$((count + 1))
  else
    echo "Failed: $src" >&2
    err=$((err + 1))
  fi
done < <(find api-src -type f -name "*.js" ! -path "*/lib/*" -print0 2>/dev/null)

echo "Copied $count files from api-src to api."
[ "$err" -gt 0 ] && echo "Failures: $err" >&2 && exit 1
echo "api/lib was not modified. Done."
