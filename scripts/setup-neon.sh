#!/usr/bin/env bash
# Complete Neon setup via CLI: create project (if needed), run schema.
# Run from project root. First time: run "npx neonctl auth" and complete browser login.
set -e
cd "$(dirname "$0")/.."
PROJECT_NAME="guilty-pleasure-treats"

echo "=== Neon setup (CLI) ==="

# 1. Auth check
if ! npx neonctl projects list &>/dev/null; then
  echo "Not logged in. Run this in your terminal (browser will open):"
  echo "  npx neonctl auth"
  echo "Then run this script again: ./scripts/setup-neon.sh"
  exit 1
fi

# 2. Create or find project
echo "Creating or finding Neon project..."
CREATE_OUT=$(npx neonctl projects create --name "$PROJECT_NAME" -o json 2>&1) || true
if echo "$CREATE_OUT" | grep -q '"id"'; then
  PROJECT_ID=$(echo "$CREATE_OUT" | node -e "let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{ try { const j=JSON.parse(d); console.log(j.project?.id||j.id||''); } catch(e){} });")
elif echo "$CREATE_OUT" | grep -qi "already exists\|name.*taken"; then
  echo "Project exists, looking up id..."
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
else
  echo "Create output: $CREATE_OUT"
  exit 1
fi

if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(echo "$CREATE_OUT" | node -e "let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{ try { const j=JSON.parse(d); console.log(j.project?.id||j.id||''); } catch(e){} });" 2>/dev/null)
fi
if [ -z "$PROJECT_ID" ]; then
  echo "Could not get project id. Create a project in Neon Console and run: POSTGRES_URL='<your-uri>' node scripts/run-schema.js"
  exit 1
fi

echo "Project id: $PROJECT_ID"
npx neonctl set-context --project-id "$PROJECT_ID"

# 3. Connection string (plain text)
CONN=$(npx neonctl connection-string 2>/dev/null | tr -d '\n\r')
if [ -z "$CONN" ]; then
  echo "Could not get connection string."
  exit 1
fi

# 4. Run schema
echo "Running schema..."
export POSTGRES_URL="$CONN"
node scripts/run-schema.js

echo ""
echo "=== Done ==="
echo "Add this to Vercel so your API uses the DB:"
echo "  Vercel Dashboard → guilty-pleasure-treats → Settings → Environment Variables"
echo "  Add: POSTGRES_URL = (the connection string from Neon)"
echo "  Or: Vercel → Storage → Connect Neon to this project (injects POSTGRES_URL)."
echo "Then redeploy: npx vercel --prod"
