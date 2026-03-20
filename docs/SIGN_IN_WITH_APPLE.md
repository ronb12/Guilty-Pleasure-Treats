# Sign in with Apple — troubleshooting

## Vercel (most common fix)

1. Open **Vercel → your project → Settings → Environment Variables → Production**.
2. Add **`APPLE_BUNDLE_ID`** exactly matching **Xcode → target → Signing & Capabilities → Bundle Identifier**, e.g.  
   `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`  
   (No extra spaces; if you have **iOS and Mac** with different IDs, use a comma-separated list.)
3. **Redeploy** after saving env vars (or “Redeploy” latest deployment).

Without this, **`POST /api/auth/apple`** returns **503** with  
`Sign in with Apple is not configured on the server.`

If the value is **wrong**, Apple’s JWT `aud` won’t match and logs show **`[auth/apple] jwtVerify failed`** (often “unexpected … aud claim”).

## App (fixed in repo)

- **macOS:** The Mac target must include the **Sign in with Apple** entitlement (`com.apple.developer.applesignin`). It was missing from `Guilty_Pleasure_Treats_Mac.entitlements` while the iOS target had it — that prevents Apple sign-in from working correctly on the Mac app.
- After pulling changes, open **Xcode → Signing & Capabilities** for the Mac target and confirm **Sign In with Apple** is listed (or add it). Rebuild.

## Apple Developer

- **Identifiers:** The App ID for each platform (iOS / macOS) must have **Sign In with Apple** enabled and match your bundle ID (e.g. `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`).
- If iOS and Mac use **different** bundle IDs, both must be listed in server env (see below).

## Server (Vercel)

`POST /api/auth/apple` returns **503** if Sign in with Apple is not configured:

```text
Sign in with Apple is not configured on the server.
```

Set in Vercel **Environment Variables**:

| Variable | Purpose |
|----------|--------|
| `APPLE_BUNDLE_ID` | Your app’s bundle ID(s). Comma-separated if iOS and Mac differ. Must match the JWT **`aud`** claim from Apple (usually the app’s bundle ID). |
| `APPLE_CLIENT_ID` | Optional; merged with `APPLE_BUNDLE_ID` for allowed audiences. |

Example:

```bash
APPLE_BUNDLE_ID=com.bradleyvirtualsolutions.Guilty-Pleasure-Treats
```

## `AuthorizationError Code=1000`

Apple reports **`ASAuthorizationError.failed` (1000)** when the **Sign in with Apple UI fails before your server runs**. It is **not** “wrong Apple ID password” — the password sheet often never completes.

**Typical causes:**

1. **Apple Developer** – App ID does not have **Sign In with Apple** enabled (Identifiers → App ID → Capabilities).
2. **Xcode** – Target **Signing & Capabilities** does not include **Sign In with Apple** (iOS and Mac targets separately).
3. **Provisioning** – Team / bundle ID mismatch; try **Product → Clean Build Folder**, delete app from device, reinstall.
4. **Simulator** – Flaky; sign in to an Apple ID under **Settings → Apple ID** in the Simulator, or test on a **physical iPhone**.
5. **macOS** – App Sandbox + **Sign In with Apple** entitlement on the Mac target (`Guilty_Pleasure_Treats_Mac.entitlements`).
6. **SwiftUI `.sheet`** – On a **real iPhone**, `SignInWithAppleButton` inside a **sheet** can fail with **1000** because `ASAuthorizationController` doesn’t get a valid **presentation anchor**. This app presents **Login** with **`.fullScreenCover`** on iOS (not a sheet) so Apple’s UI can anchor correctly. If you fork the UI, avoid nesting Sign in with Apple in a sheet, or use `ASAuthorizationController` with a proper `presentationAnchor`.

After fixing capabilities, rebuild and run again.

---

## Common errors

| Symptom | Likely cause |
|--------|----------------|
| Works on iPhone, fails on Mac | Missing Mac **Sign in with Apple** entitlement or capability. |
| “Sign in with Apple is not configured on the server” | Missing `APPLE_BUNDLE_ID` / `APPLE_CLIENT_ID` on Vercel. |
| “could not be verified” / 401 from API | Wrong **audience** (bundle ID mismatch), or **nonce** mismatch (rare if using the stock `LoginView` flow). |
| Email/password works, Apple does not | Usually server JWT verification or env; check Vercel logs for `[auth/apple]`. |
| **1000** only on device, login in a **sheet** | Presentation anchor issue; use **fullScreenCover** or custom `ASAuthorizationController` (see §1000 cause 6). |

## Verify

1. Xcode: Run app, tap **Sign in with Apple**, watch **Console** for `[Auth] signInWithApple` logs.
2. Vercel: Function logs for `jwtVerify failed` or `nonce mismatch`.
