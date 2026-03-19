# Splash screen

## In-app splash (SplashView)

The app shows **SplashView** for 2 seconds on launch, then transitions to the main tab bar (Home, Menu, Cart, Rewards, More).

**Content:**
- Full-screen background: **AppSecondary** color
- Centered **LandingLogo** image (max 200×200 pt)
- Title: **"Guilty Pleasure Treats"** (AppTextPrimary, title font)

**Files:**
- `Guilty Pleasure Treats/Views/Splash/SplashView.swift` — splash UI
- `Guilty Pleasure Treats/Views/RootView.swift` — shows SplashView then `TabView` (Home, Menu, Cart, Rewards, More)

**To change splash duration:** In `RootView.swift`, edit the delay: `.now() + 2.0` (seconds).

**To use a different logo:** In `SplashView.swift`, change `Image("LandingLogo")` to `Image("HomeLogo")` or another asset name.

---

## System launch screen (before app loads)

The **system** launch screen is the static screen iOS shows while the app binary loads. It is controlled by:

- **Build Settings:** `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (Xcode generates it from the app icon and display name), or
- A custom **Launch Screen** storyboard / Info.plist configuration.

To match the in-app splash, you can add a custom launch screen:

1. In Xcode: **File → New → File → Launch Screen**, or add **Info.plist** keys:
   - `UILaunchScreen` dictionary with `UIImageName` = `LandingLogo`, `UIColorName` = `AppSecondary`, etc. (iOS 14+).
2. Or create a **LaunchScreen.storyboard** with an image view (LandingLogo) and background color.

If you only need the in-app splash to be correct, the updated **SplashView** and **RootView** are enough.

---

## App entry point

Ensure the app shows **RootView** (which includes the splash). In your `@main` App file (e.g. `Guilty_Pleasure_TreatsApp.swift`):

```swift
WindowGroup {
    RootView()   // not ContentView()
}
```

If you still see `ContentView()` there, replace it with `RootView()` so the splash and tab bar are used.
