#!/usr/bin/env bash
# Opens Vercel Dashboard so you can link a Blob store to this project.
# After opening: go to Storage → open a Blob store → Connect to project → guilty-pleasure-treats → select environments → Save.
# Then redeploy: vercel --prod (or Redeploy from Deployments).

set -e
PROJECT_NAME="guilty-pleasure-treats"
# Team from .vercel/project.json orgId; use dashboard root so user can navigate to Storage
URL="https://vercel.com/dashboard"
echo "Opening Vercel Dashboard..."
echo "1. Go to Storage (left sidebar)"
echo "2. Open one of your Blob stores (e.g. guilty-pleasure-treats-blob)"
echo "3. Connect to project → select $PROJECT_NAME → Production, Preview, Development → Save"
echo "4. Redeploy: vercel --prod"
open "$URL" 2>/dev/null || xdg-open "$URL" 2>/dev/null || echo "Open: $URL"
