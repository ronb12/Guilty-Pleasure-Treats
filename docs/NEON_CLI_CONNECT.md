# Connect to Neon with the Neon CLI

Use the [Neon CLI](https://neon.tech/docs/reference/neon-cli) to authenticate and connect to your Neon database from the terminal (no need to copy connection strings from the dashboard).

**If `branches list` or `connection-string` fails with “could not be authorized due to an internal error”:** upgrade the CLI — this repo pins **neonctl 2.22+** (`npm install`). Older 1.x clients can hit broken API responses against current Neon.

**If you see “Multiple roles found … provide --role-name”:** Neon added extra roles (e.g. `authenticator`, `authenticated`). Use the owner role, which this repo defaults to **`neondb_owner`** (see `scripts/neon-connect.sh`). Override with `NEON_ROLE_NAME=your_role` if needed.

**If you see “org_id is required”:** set context with explicit IDs (Step 3 below). In some terminals `neonctl set-context` does not show prompts.

## 1. Install the Neon CLI

**Option A – npm (project or global)**

```bash
# From project root: install as dev dependency (then use npx)
npm install -D neonctl

# Or install globally
npm i -g neonctl
```

**Option B – Homebrew (macOS)**

```bash
brew install neonctl
```

**Option C – Run without installing**

```bash
npx neonctl <command>
```

## 2. Authenticate

One-time login (opens browser):

```bash
npx neonctl auth
# or, if installed globally: neon auth
```

Or set an API key (e.g. from [Neon Console → Account → API Keys](https://console.neon.tech/app/settings/api-keys)):

```bash
export NEON_API_KEY='your-api-key'
```

## 3. Set context (required)

The CLI needs to know which org and project to use. **Use explicit IDs** (prompts often don’t appear):

```bash
npx neonctl set-context --org-id YOUR_ORG_ID --project-id YOUR_PROJECT_ID
```

Replace `YOUR_ORG_ID` and `YOUR_PROJECT_ID` with values from the [Neon Console](https://console.neon.tech):

- **Org ID:** Neon Console → **Organization settings** (or the URL when you’re in a project).
- **Project ID:** Open your project → **Settings** → **General**, or from the project URL.

Then run:

```bash
npm run neon:connect
```

**Alternative (no context file):** pass IDs when connecting:

```bash
NEON_ORG_ID=your_org_id NEON_PROJECT_ID=your_project_id npm run neon:connect
```

That sets context for this run and then opens psql.

## 4. Connect to the database

**Open an interactive `psql` session** (requires [PostgreSQL client](https://www.postgresql.org/download/) with `psql` installed):

```bash
npx neonctl connection-string --role-name neondb_owner --psql
```

**Run a single query:**

```bash
npx neonctl connection-string --role-name neondb_owner --psql -- -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
```

**Run an SQL file (e.g. our schema):**

```bash
npx neonctl connection-string --role-name neondb_owner --psql -- -f scripts/run-all-schema-in-neon.sql
```

## 5. Use the connection string with our Node scripts

To run the project’s schema script using the CLI’s connection string:

```bash
# Export the connection string (no --psql), then run the script
export POSTGRES_URL=$(npx neonctl connection-string --role-name neondb_owner)
node scripts/run-missing-tables.js
# Or use the npm script:
npm run neon:run-schema
```

One-liner (after `npx neonctl auth`):

```bash
POSTGRES_URL=$(npx neonctl connection-string --role-name neondb_owner) npm run neon:run-schema
```

If you get “permission denied” or the script can’t connect, copy the string from `npx neonctl connection-string` and set it manually:

```bash
export POSTGRES_URL='postgresql://user:pass@ep-xxx.region.aws.neon.tech/dbname?sslmode=require'
node scripts/run-missing-tables.js
```

## Quick reference

| Goal                    | Command |
|-------------------------|--------|
| Login                   | `npx neonctl auth` |
| Open psql               | `npx neonctl connection-string --role-name neondb_owner --psql` (or `npm run neon:connect`) |
| Get connection string   | `npx neonctl connection-string --role-name neondb_owner` |
| **Run DB migrations** (this repo) | `npm run neon:migrate:cli` (uses CLI connection string + `scripts/run-missing-tables.js`) |
| List projects           | `npx neonctl projects list` |
| List branches           | `npx neonctl branches list` |
| Set project/branch      | `npx neonctl set-context` |
