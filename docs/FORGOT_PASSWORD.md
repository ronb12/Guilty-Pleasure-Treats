# Forgot / reset password

## One-time database setup

The API stores short-lived reset tokens in **`password_reset_tokens`**. Create the table on your Neon database:

```bash
# From repo root (uses Vercel-pulled env)
node --env-file=.env.neon scripts/run-missing-tables.js
```

Or run the SQL in `scripts/migrations/add-password-reset-tokens.sql` in the Neon SQL editor.

Without this table, `POST /api/auth/forgot-password` returns **503** (“Password reset is not ready”).

## How it works

1. **Forgot password** — `POST /api/auth/forgot-password` with `{ "email": "..." }`.  
   If the account can use email/password (Neon **credential** account and/or `users.password_hash`), the response includes `{ "token": "..." }` for the in-app **Set new password** screen.  
   Apple-only accounts (no password) get `{}` — the app explains that reset isn’t available.

2. **Reset password** — `POST /api/auth/reset-password` with `{ "token": "...", "newPassword": "..." }`.  
   Updates `public.users.password_hash` and **`neon_auth.account`** (credential) when present so sign-in matches **login** (Neon Auth first, then DB fallback).

## Env

Same as login: **`NEON_AUTH_URL`**, **`POSTGRES_URL`** / **`DATABASE_URL`**.
