#!/usr/bin/env bash
# Run scripts/run-missing-tables.js using a connection string from Neon CLI.
# Prereqs: npx neonctl auth (or NEON_API_KEY), and set-context if needed.
#
# Usage (from repo root):
#   npm run neon:migrate:cli
#
# Optional:
#   NEON_ORG_ID=... NEON_PROJECT_ID=... npm run neon:migrate:cli   # set context first
#   NEON_ROLE_NAME=neondb_owner npm run neon:migrate:cli           # default role

set -e
cd "$(dirname "$0")/.."

if [ -n "${NEON_ORG_ID:-}" ] && [ -n "${NEON_PROJECT_ID:-}" ]; then
  npx neonctl set-context --org-id "$NEON_ORG_ID" --project-id "$NEON_PROJECT_ID"
fi

ROLE="${NEON_ROLE_NAME:-neondb_owner}"
export POSTGRES_URL
POSTGRES_URL="$(npx neonctl connection-string --role-name "$ROLE")"

if [ -z "$POSTGRES_URL" ]; then
  echo "Failed to get connection string. Run: npx neonctl auth"
  echo "See docs/NEON_CLI_CONNECT.md"
  exit 1
fi

echo "Running run-missing-tables.js against Neon (role: $ROLE)..."
node scripts/run-missing-tables.js
