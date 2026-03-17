#!/usr/bin/env bash
# Run Neon setup (schema + admin user) using Neon CLI for the connection string.
# Usage:
#   1. Link to existing project:  ./scripts/neon-setup-cli.sh tiny-wave-77244048
#   2. Or let script create/find project:  ./scripts/neon-setup-cli.sh
# First time: run "npx neonctl auth" and complete browser login.
set -e
cd "$(dirname "$0")/.."

PROJECT_ID="${1:-}"
PROJECT_NAME="guilty-pleasure-treats"

echo "=== Neon setup (Neon CLI) ==="

# 1. Auth check
if ! npx neonctl projects list &>/dev/null; then
  echo "Not logged in. Run (browser will open):"
  echo "  npx neonctl auth"
  echo "Then run this script again."
  exit 1
fi

# 2. Use existing project or create/find one
if [ -n "$PROJECT_ID" ]; then
  echo "Using existing project: $PROJECT_ID"
  npx neonctl set-context --project-id "$PROJECT_ID"
else
  echo "Creating or finding Neon project..."
  CREATE_OUT=$(npx neonctl projects create --name "$PROJECT_NAME" -o json 2>&1) || true
  if echo "$CREATE_OUT" | grep -q '"id"'; then
    PROJECT_ID=$(echo "$CREATE_OUT" | node -e "let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{ try { const j=JSON.parse(d); console.log(j.project?.id||j.id||''); } catch(e){} });")
  elif echo "$CREATE_OUT" | grep -qi "already exists\|name.*taken"; then
    LIST=$(npx neonctl projects list -o json 2>/dev/null)
    PROJECT_ID=$(echo "$LIST" | node -e "
      let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
        try {
          const j=JSON.parse(d);
          const arr = j.projects || j.Projects || (Array.isArray(j) ? j : []);
          const p = arr.find(x => (x.name||'').toLowerCase() === 'guilty-pleasure-treats');
          console.log(p ? (p.id || p.Id) : '');
        } catch(e){}
      });
    ")
  fi
  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(echo "$CREATE_OUT" | node -e "let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{ try { const j=JSON.parse(d); console.log(j.project?.id||j.id||''); } catch(e){} });" 2>/dev/null)
  fi
  if [ -z "$PROJECT_ID" ]; then
    echo "Could not get project id. Run with your project id: ./scripts/neon-setup-cli.sh tiny-wave-77244048"
    exit 1
  fi
  echo "Project id: $PROJECT_ID"
  npx neonctl set-context --project-id "$PROJECT_ID"
fi

# 3. Connection string
CONN=$(npx neonctl connection-string 2>/dev/null | tr -d '\n\r')
if [ -z "$CONN" ]; then
  echo "Could not get connection string. Check neonctl and try again."
  exit 1
fi

# 4. Run full setup (schema + admin user)
echo "Running schema + admin user (api/neon-setup.sql)..."
export POSTGRES_URL="$CONN"
node scripts/run-neon-setup.js

echo ""
echo "=== Done ==="
echo "Add POSTGRES_URL to Vercel (Settings → Environment Variables) with this connection string, then redeploy."
echo "App login: ronellbradley@hotmail.com / password1234"
