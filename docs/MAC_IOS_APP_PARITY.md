# macOS and iOS app parity

The **Guilty Pleasure Treats** and **Guilty Pleasure Treats (Mac)** Xcode targets both use the **same** synchronized folder: `Guilty Pleasure Treats/Guilty Pleasure Treats/`. New Swift files (including features like product sizes) are compiled for **both** platforms automatically—no separate copy for Mac.

## What to do after feature work

1. Build **both** schemes occasionally:
   - **Guilty Pleasure Treats** — iOS / iPadOS / Catalyst
   - **Guilty Pleasure Treats (Mac)** — native macOS app
2. **`CURRENT_PROJECT_VERSION`** may differ between iOS and Mac if you ship them on different schedules (Mac was historically lower).
3. Use `#if os(iOS)` / `#if os(macOS)` only where platform APIs differ (e.g. UIKit vs AppKit, Stripe Payment Sheet on iPhone).

## Known differences

- **Stripe Payment Sheet** is linked for the iOS target; Mac checkout may use other flows (e.g. web / pay at pickup)—see app README.
- Some admin or export UI is conditional per platform; core menu, cart, product detail, and orders are shared.
