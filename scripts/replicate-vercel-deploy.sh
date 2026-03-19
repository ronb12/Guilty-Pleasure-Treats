#!/usr/bin/env bash
# Replicate the last successful Vercel deployment method.
# Same steps as DEPLOY.md: sync api-src -> api, then deploy to production.
# Run in Terminal.app: ./scripts/replicate-vercel-deploy.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> [1/2] Sync api-src -> api (same as last successful deploy)..."
bash scripts/sync-api-for-vercel.sh

echo ""
echo ">>> [2/2] Deploy to Vercel production..."
vercel --prod

echo ""
echo "Done. Same method as last successful Vercel deployment."
