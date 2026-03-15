# App Store Requirements Checklist — Guilty Pleasure Treats

Use this checklist before submitting to the App Store. Items marked ✅ are already addressed in the project; ⬜ need your action.

---

## 1. Technical & Identity

| Requirement | Status | Notes |
|-------------|--------|--------|
| **Bundle ID** | ✅ | `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats` |
| **Version (CFBundleShortVersionString)** | ✅ | 1.0 in Info.plist |
| **Build (CFBundleVersion)** | ✅ | 1 in Info.plist |
| **Display Name (CFBundleDisplayName)** | ✅ | Guilty Pleasure Treats |
| **Copyright (NSHumanReadableCopyright)** | ✅ | © 2026 Bradley Virtual Solutions |
| **App Icon 1024×1024** | ⬜ | Add a 1024×1024 PNG to `Assets.xcassets/AppIcon.appiconset/`. Required for submission. |
| **Launch Screen** | ✅ | Generated via build setting (UILaunchScreen_Generation) |
| **Deployment Target** | ⬜ | Currently iOS 26.2. Consider lowering to iOS 17.0 or 18.0 in Xcode for wider device support. |
| **Code Signing** | ✅ | Automatic; Development Team set (4SQJ3AH62S) |

---

## 2. Privacy & Permissions

| Requirement | Status | Notes |
|-------------|--------|--------|
| **NSPhotoLibraryUsageDescription** | ✅ | Added for custom cake / AI design photo upload |
| **NSCameraUsageDescription** | ✅ | Added for design reference capture |
| **Push Notifications (UIBackgroundModes)** | ✅ | remote-notification in Info.plist |
| **ITSAppUsesNonExemptEncryption** | ✅ | Set to `false` (no custom crypto); export compliance simplified |
| **Privacy Policy URL** | ⬜ | Required if you collect user data (e.g. account, orders). Add in App Store Connect and optionally in-app. |
| **Sign in with Apple** | ⬜ | If you offer third-party login (e.g. Google/email), you must also offer Sign in with Apple (Guideline 4.8). |

---

## 3. Entitlements & Capabilities

| Requirement | Status | Notes |
|-------------|--------|--------|
| **Push Notifications** | ✅ | aps-environment in entitlements (use production profile for App Store) |
| **iCloud / CloudKit** | ⬜ | Currently in entitlements. Remove if the app does not use iCloud/CloudKit to avoid unused capability. |

---

## 4. App Store Connect & Metadata

| Requirement | Status | Notes |
|-------------|--------|--------|
| **App name** | ⬜ | Must match or align with CFBundleDisplayName |
| **Subtitle** | ⬜ | Short tagline (30 chars) |
| **Screenshots** | ⬜ | Required for each device size (e.g. 6.7", 6.5", 5.5"). No placeholder text. |
| **Description** | ⬜ | Clear description of bakery ordering, custom cakes, AI designer |
| **Keywords** | ⬜ | Relevant search terms |
| **Support URL** | ⬜ | Working URL (e.g. website or contact page) |
| **Privacy Policy URL** | ⬜ | Required if collecting data; must be a live URL |
| **Age Rating** | ⬜ | Complete questionnaire in App Store Connect (likely 4+) |
| **Pricing** | ⬜ | Free or paid; set availability |

---

## 5. App Review Guidelines (Summary)

| Area | Action |
|------|--------|
| **Safety** | No objectionable content; user data handled securely; accurate developer/contact info. |
| **Performance** | App must be complete, not crash, and match the description. Test on real devices. |
| **Business** | Physical goods (bakery orders) may use external payment (Stripe). In-app purchases only for digital goods/subscriptions if applicable. |
| **Design** | No copycat or spam; if login is offered, consider Sign in with Apple if other third-party login is used. |
| **Legal** | Privacy policy and terms where required; no IP infringement. |

---

## 6. Pre-Submission Tests

- [ ] Build with **Release** and run on a physical device.
- [ ] Complete a full flow: browse, add to cart, checkout (or AI design → confirm).
- [ ] Test with no network / airplane mode; app should fail gracefully.
- [ ] Confirm no debug logs or test credentials in production build.
- [ ] Verify Stripe/Firebase use **production** config and no secret keys in the app bundle.
- [ ] Ensure Push Notifications use production APNs when submitting.

---

## 7. Build for Submission

1. In Xcode: **Product → Archive**.
2. In Organizer: **Distribute App → App Store Connect**.
3. Use the **production** provisioning profile so **aps-environment** is `production` for Push.
4. After upload, complete version metadata and submit for review in App Store Connect.

---

## Quick Fixes Already Applied

- **Info.plist**: Added `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, `ITSAppUsesNonExemptEncryption`, `UIRequiresFullScreen` (false for iPad multitasking).
- **Identity**: CFBundleDisplayName, version, build, and copyright set.

Complete the ⬜ items above and run the pre-submission tests before submitting.
