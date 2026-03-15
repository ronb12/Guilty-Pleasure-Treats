# Full App: Packages and Entry Point

All app source files are now in this folder and are **included in the Xcode target** (File System Synchronized Root Group).

## To build and run the **full** bakery app (Splash, Home, Menu, Cart, Checkout, Orders, Rewards, Admin, Custom Cake, AI Cake Designer)

1. **Add Firebase iOS SDK**  
   Xcode → **File → Add Package Dependencies…**  
   URL: `https://github.com/firebase/firebase-ios-sdk`  
   Add: **FirebaseAuth**, **FirebaseFirestore**, **FirebaseStorage**, **FirebaseMessaging**.

2. **Add Stripe iOS SDK** (optional, for payments)  
   URL: `https://github.com/stripe/stripe-ios`  
   Add: **StripePaymentSheet**.

3. **Switch the app entry to the full UI**  
   In `Guilty_Pleasure_TreatsApp.swift`:
   - Add `import FirebaseCore` and `import FirebaseMessaging`.
   - Add `@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate`.
   - Replace `ContentView()` with `RootView()` in the `WindowGroup`.
   - Add an `AppDelegate` class that calls `FirebaseApp.configure()` and registers for remote notifications (see the `GuiltyPleasureTreats` folder’s `App/GuiltyPleasureTreatsApp.swift` for reference).

4. **Add `GoogleService-Info.plist`**  
   From your Firebase project, and add it to this target.

Until you do the above, the project may not build because of `import FirebaseCore` (and similar) in the copied files. You can either add the packages and entry point as above, or temporarily remove/comment the Firebase-dependent files if you only want to run the simpler ContentView + AI Cake Designer flow.
