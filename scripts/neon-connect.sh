#!/usr/bin/env bash
# Set Neon CLI context from env vars, then open psql.
# Usage:
#   NEON_ORG_ID=your_org_id NEON_PROJECT_ID=your_project_id npm run neon:connect
# Or set context once with: npx neonctl set-context --org-id ID --project-id ID
#
# neonctl 2.x + branches with multiple Postgres roles (e.g. neondb_owner + RLS roles)
# require --role-name. Override with NEON_ROLE_NAME if yours differs.

set -e
if [ -n "$NEON_ORG_ID" ] && [ -n "$NEON_PROJECT_ID" ]; then
  npx neonctl set-context --org-id "$NEON_ORG_ID" --project-id "$NEON_PROJECT_ID"
fi
ROLE="${NEON_ROLE_NAME:-neondb_owner}"
exec npx neonctl connection-string --role-name "$ROLE" --psql "$@"
