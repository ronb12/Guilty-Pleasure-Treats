# Account creation and login: App ↔ Vercel ↔ Neon

This doc confirms that when a user creates an account in the app, the app, Vercel API, and Neon database are all updated so the user can sign in successfully (including after closing the app and reopening).

---

## 1. App (iOS)

- **Sign up:** User enters email, password, optional display name → `AuthService.signUp` sends `POST /api/auth/signup` with `{ email, password, displayName }`.
- **On success:** App receives `{ token, user }`, then:
  - Saves `token` to `UserDefaults` and sets `VercelService.shared.authToken` so all API calls use it.
  - Sets `authState = .signedIn` and `userProfile` so the UI shows the user as logged in.
- **Later (reopen app):** `AuthService.restoreSession()` loads the stored token, sets `VercelService.shared.authToken`, and calls `GET /api/users/me` with `Authorization: Bearer <token>`. If the API returns the user, the app stays signed in.

So the app “registers” the account by storing the token and auth state; subsequent requests use the same token against Vercel.

---

## 2. Vercel API

- **Signup** (`api-src/auth/signup.js`):
  - Validates email and password (min 6 chars).
  - **If `NEON_AUTH_URL` is set (Neon Auth / Better Auth):**
    - Calls Neon Auth `POST .../sign-up/email` to create the user there.
    - Gets a JWT via `GET .../token`, then calls `getOrCreateUserFromNeonPayload(payload)` which **ensures a row exists in the Neon `users` table** (by `neon_auth_id` or email, or inserts a new row).
    - Returns `{ token: jwt, user }` to the app.
  - **If `NEON_AUTH_URL` is not set (direct DB):**
    - Uses `POSTGRES_URL` (Neon): `INSERT INTO users (email, display_name, password_hash, ...)` then `createSession(user.id)` → `INSERT INTO sessions`.
    - Returns `{ token: session.id, user }` to the app.
- **Login** (`api-src/auth/login.js`):
  - **If Neon Auth:** Proxies to Neon Auth sign-in, gets JWT, then resolves user from Neon `users` via `getOrCreateUserFromNeonPayload`.
  - **If direct DB:** Loads user by email from Neon `users`, verifies password, creates a new session in `sessions`, returns `{ token: session.id, user }`.
- **Restore session** (`api-src/users/me.js`): Accepts `Authorization: Bearer <token>` (session UUID or JWT). Validates token (JWT via Neon Auth JWKS, or session UUID via Neon `sessions` table) and returns the same `user` shape. So the app can stay logged in after restart.

So Vercel “registers” the account by either (a) creating the user in Neon Auth and a row in Neon `users`, or (b) creating the user and session rows in Neon only.

---

## 3. Neon

- **Tables used:**
  - **`users`:** `id`, `email`, `display_name`, `password_hash` (direct DB only), `apple_id`, `neon_auth_id` (if migrated), `is_admin`, `points`, etc.
  - **`sessions`:** `id`, `user_id` (FK to `users`), `expires_at`. Used only when **not** using Neon Auth; when using Neon Auth, the token is a JWT and no session row is created for login.
- **Signup (direct DB):** One new row in `users`, one new row in `sessions`. Login later uses that `users` row and creates a new session.
- **Signup (Neon Auth):** Neon Auth stores the credential in its own store; our API then calls `getOrCreateUserFromNeonPayload`, which inserts (or links) a row in our `users` table. So Neon “registration” is the presence of that row in `users` (and optionally `neon_auth_id` linking to Neon Auth).

So Neon “registers” the account by having a `users` row (and, in direct-DB mode, a `sessions` row at signup). That is what allows:
- **Login:** User is found by email (and password in direct DB, or Neon Auth in the other mode).
- **Restore session:** Token is validated (session lookup in `sessions` or JWT verification) and user is loaded from `users`.

---

## Summary

| Step | App | Vercel | Neon |
|------|-----|--------|------|
| **Sign up** | Sends signup request; saves token & sets auth state | Creates user (Neon Auth or direct DB) and ensures `users` row; returns token + user | Row in `users` (and in direct DB, row in `sessions`) |
| **Use app** | Sends `Authorization: Bearer <token>` on API calls | Validates token (JWT or session), returns data | Session or JWT lookup; user from `users` |
| **Reopen app** | Restores token, calls `GET /api/users/me` | Validates token, returns user | Same as above |
| **Login again** | Sends login request | Validates credentials, returns new token + user | User found in `users`; (direct DB: new row in `sessions`) |

So **yes: the app, Vercel, and Neon all “register” the account on signup**, and the user can successfully log in (and stay logged in after restart) as long as:

1. **Vercel env**
   - **`POSTGRES_URL`** is set to your Neon connection string (same branch you use for production). Required for both modes.
   - **`NEON_AUTH_URL`** (optional): If set, signup/login use Neon Auth and our API still ensures a row in Neon `users` via `getOrCreateUserFromNeonPayload`.
2. **Neon**
   - Schema applied: `users` and `sessions` (see `api/neon-setup.sql` or `api/schema.sql`). If you use Neon Auth and link by `neon_auth_id`, run `api/migrate-neon-auth.sql` to add that column.
3. **App**
   - `vercelBaseURLString` (or equivalent) points at your Vercel API so signup/login and `users/me` hit the same backend.

If login fails after a successful signup, check: same `POSTGRES_URL` (and Neon branch) everywhere, Neon Auth URL and JWKS reachable when using Neon Auth, and that the app’s base URL is correct.
