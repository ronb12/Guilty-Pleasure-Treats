# Stripe iOS dependency (Swift Package Manager)

The Xcode project uses **`https://github.com/stripe/stripe-ios-spm`**, not `stripe/stripe-ios`.

The main `stripe-ios` repository is very large; cloning it for SPM often fails on limited disk space and Xcode then reports **“Missing package product 'StripePaymentSheet'”**. The **`-spm`** mirror is the supported lightweight SPM distribution (same products, e.g. `StripePaymentSheet`).

If packages still fail to resolve:

1. Free several GB of disk space.
2. In Xcode: **File → Packages → Reset Package Caches**, then **Resolve Package Versions**.
3. Optionally remove stale clones: `rm -rf ~/Library/Caches/org.swift.swiftpm/repositories/stripe-ios-*`
