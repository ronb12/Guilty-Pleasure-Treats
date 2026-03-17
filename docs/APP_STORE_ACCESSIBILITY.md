# App Store — iPhone Accessibility Checklist

Use this when filling out **App Store Connect → Your App → App Store → iPhone App → Accessibility**.

Only **check features that your app actually supports**. Apple can reject or flag apps that claim support users cannot use for common tasks.

---

## What to check (claim support)

| Feature | Support in app | Action |
|--------|-----------------|--------|
| **VoiceOver** | ✅ | SwiftUI provides default labels for buttons and text. Product images and key actions have `.accessibilityLabel` / `.accessibilityHint`. Main flows (browse menu, add to cart, checkout, sign in, settings) are usable with VoiceOver. |
| **Voice Control** | ✅ | Same as VoiceOver; standard controls and labels work with Voice Control. |
| **Larger Text** | ✅ | App uses semantic fonts (`.headline`, `.body`, `.caption`, etc.) that scale with Dynamic Type. |
| **Dark Interface** | ✅ | App supports Light / System / Dark in Settings (AppearanceManager, `preferredColorScheme`). |
| **Reduced Motion** | ✅ | Splash screen respects `UIAccessibility.isReduceMotionEnabled` (shorter/skipped animations). |
| **Differentiate Without Color Alone** | ⚠️ Verify | UI uses text, icons, and layout as well as color. Confirm no critical info is conveyed only by color (e.g. status also has icon or label). |
| **Sufficient Contrast** | ⚠️ Verify | Pink/light theme; ensure text meets contrast guidelines (e.g. in Settings and Legal). |

---

## Do **not** check (no support or N/A)

| Feature | Reason |
|--------|--------|
| **Captions** | App has no video or audio content that would require captions. |
| **Audio Descriptions** | App has no video content that would require audio descriptions. |

---

## Summary for App Store Connect

**Check (claim):**
- VoiceOver  
- Voice Control  
- Larger Text  
- Dark Interface  
- Reduced Motion  

**Optionally check after you verify in the app:**
- Differentiate Without Color Alone  
- Sufficient Contrast  

**Do not check:**
- Captions  
- Audio Descriptions  

---

## Code references (for your own audit)

- **Reduced Motion:** `SplashView.swift` — `UIAccessibility.isReduceMotionEnabled`, shorter animations when true.
- **Dark Interface:** `AppearanceManager.swift` — `AppAppearance.dark`, `preferredColorScheme`.
- **VoiceOver / labels:** `ProductDetailView` — product image `.accessibilityLabel`, Add to Cart `.accessibilityHint`; `SplashView` — logo `.accessibilityLabel`. Tab bar and buttons use SwiftUI defaults (Label/Text).
