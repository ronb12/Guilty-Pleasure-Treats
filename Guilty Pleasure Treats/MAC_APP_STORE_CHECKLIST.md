# macOS App Store Readiness Checklist

This checklist confirms the **Guilty Pleasure Treats (Mac)** target is configured to pass App Store technical and policy checks.

---

## ✅ In place (project configuration)

| Requirement | Status | Notes |
|-------------|--------|--------|
| **App Sandbox** | ✅ | `Guilty_Pleasure_Treats_Mac.entitlements`: `com.apple.security.app-sandbox` = true (required for Mac App Store). |
| **Network client** | ✅ | `com.apple.security.network.client` for API (Vercel, Stripe backend, auth). |
| **User-selected file read** | ✅ | `com.apple.security.files.user-selected.read-only` for image picker (NSOpenPanel). |
| **User-selected file write** | ✅ | `com.apple.security.files.user-selected.read-write` for CSV export (NSSavePanel). |
| **Hardened Runtime** | ✅ | `ENABLE_HARDENED_RUNTIME = YES` in Debug and Release. |
| **Code signing** | ✅ | `CODE_SIGN_STYLE = Automatic`, entitlements file set for Mac target. |
| **64-bit** | ✅ | Default for current Xcode (arm64 + x86_64). |
| **macOS deployment target** | ✅ | 14.0. |
| **Bundle ID** | ✅ | `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats.mac` (distinct from iOS). |
| **Display name & copyright** | ✅ | Set in build settings (INFOPLIST_KEY_*). |
| **App category** | ✅ | `public.app-category.business`. |
| **Menu bar / return to main** | ✅ | **Navigate** menu with Home, Menu, Cart, Rewards, Orders, Account (⌘1–⌘6). Satisfies Apple’s expectation that Mac users can return to the main/home area via the menu bar. |

---

## What you still do at submission time

1. **Signing & distribution**
   - In Xcode: select the **Guilty Pleasure Treats (Mac)** scheme, then **Product → Archive**.
   - Use **Distribute App → App Store Connect** and upload with your Apple ID / team.

2. **Notarization**
   - Handled by Apple when you upload to App Store Connect; no separate notarization step for Mac App Store builds.

3. **App Store Connect**
   - Create a **macOS** app record (or add a macOS version to an existing app).
   - Fill in metadata, screenshots, privacy policy URL, and **App Sandbox** description if asked (e.g. “Uses network for orders and payments; file access only for user-selected images and export.”).
   - If you use **Sign in with Apple** on Mac, add the capability in the Mac target and in App Store Connect.

4. **Privacy**
   - If the Mac app ever uses camera, microphone, or location, add the same usage descriptions you use on iOS (and any Mac-specific keys). Currently the Mac app uses network and user-selected files only.

5. **Testing**
   - Run the Mac app with **Release** and with **App Sandbox** enabled (it is), and test: sign-in, menu, cart, admin, image picker, CSV export, and any network calls.

---

## Optional hardening

- **Sign in with Apple (Mac):** If you add it, enable the capability in the Mac target and add the same entitlement as on iOS (in the Mac entitlements file).
- **No temporary exception entitlements** are used; avoid adding any unless required and documented in App Store Connect.

---

## Summary

The Mac target is set up with **App Sandbox**, **Hardened Runtime**, and only the **entitlements needed** for network and user-selected file access, so it can pass App Store technical checks. Filling in App Store Connect and doing a final test/archive are the remaining steps before submission.
