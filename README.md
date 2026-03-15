# Guilty Pleasure Treats

A full iOS bakery ordering app built with **Swift**, **SwiftUI**, **MVVM**, **Firebase**, and **Stripe**. Customers can browse baked goods, add items to the cart, and place orders for pickup or delivery with Stripe or Apple Pay.

## Features

- **Splash Screen** – Bakery logo and name
- **Home** – Featured treats, promotions banner, browse menu
- **Menu** – Products by category (Cupcakes, Cookies, Cakes, Brownies, Seasonal Treats)
- **Product Detail** – Image, description, price, quantity, special instructions, Add to Cart
- **Cart** – Line items, quantity controls, subtotal/tax/total, checkout
- **Checkout** – Name, phone, pickup/delivery, date & time, Stripe / Apple Pay / Pay at pickup
- **Order Confirmation** – Summary and estimated pickup time
- **Orders** – Customer order history (and all orders for admin)
- **Admin (hidden)** – 5 taps on splash: add/edit products, mark sold out, view/update orders
- **Custom Cake Builder** – Size, flavor, frosting, message, design photo; save to Firestore and add to cart
- **AI Cake Designer** – Size, flavor, frosting, design description; generate cake image via AI API, preview, confirm and add to order (image and details saved to Firestore/Storage)

## Tech Stack

- **Swift** & **SwiftUI**
- **MVVM** (ViewModels for Home, Menu, Cart, Checkout, Orders, Admin)
- **Firebase**: Auth, Firestore (products, orders, users), Storage (product images), Cloud Messaging (push)
- **Stripe**: Payment Sheet (card + Apple Pay) via your backend

## Project Structure

```
GuiltyPleasureTreats/
├── App/
│   └── GuiltyPleasureTreatsApp.swift    # Entry, Firebase init
├── Models/
│   ├── Product.swift
│   ├── CartItem.swift
│   ├── Order.swift
│   └── UserProfile.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── MenuViewModel.swift
│   ├── CheckoutViewModel.swift
│   ├── OrdersViewModel.swift
│   └── AdminViewModel.swift
├── Views/
│   ├── RootView.swift
│   ├── Splash/
│   ├── Home/
│   ├── Menu/
│   ├── ProductDetail/
│   ├── Cart/
│   ├── Checkout/
│   ├── OrderConfirmation/
│   ├── Orders/
│   ├── Admin/
│   └── Components/
├── Services/
│   ├── FirebaseService.swift
│   ├── AuthService.swift
│   ├── CartManager.swift
│   ├── StripeService.swift
│   ├── NotificationService.swift
│   └── SampleDataService.swift
└── Utilities/
    ├── AppConstants.swift
    └── Extensions/
```

## Getting Started

### 1. Create the Xcode Project

1. Open **Xcode** → **File → New → Project**.
2. Choose **App** (iOS), then **Next**.
3. Product Name: **GuiltyPleasureTreats**, Interface: **SwiftUI**, Language: **Swift**, Storage: **None**.
4. Save in the same folder as this README (or move the existing `GuiltyPleasureTreats` source folder into the new project).

### 2. Add Source Files

- Add the entire **GuiltyPleasureTreats** folder (App, Models, ViewModels, Views, Services, Utilities) to the app target so all `.swift` files are compiled.

### 3. Firebase

- Follow **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** to create a Firebase project, add iOS app, download `GoogleService-Info.plist`, enable Auth/Firestore/Storage/Messaging, and add the Firebase iOS SDK via Swift Package Manager.

### 4. Stripe

1. **Add Stripe iOS SDK**  
   - Xcode: **File → Add Package Dependencies…**  
   - URL: `https://github.com/stripe/stripe-ios` (or `https://github.com/stripe/stripe-ios-spm` if you use the SPM mirror).  
   - Add product **StripePaymentSheet** (and **StripeApplePay** if you use Apple Pay).

2. **Configure in app**  
   - In `GuiltyPleasureTreatsApp.swift` (or `AppDelegate`), call:
   ```swift
   StripeService.configure(publishableKey: "pk_test_...")
   ```
   Use your **publishable key** from the [Stripe Dashboard](https://dashboard.stripe.com/apikeys).

3. **Backend for payments**  
   - Stripe requires a backend to create [PaymentIntents](https://stripe.com/docs/payments/payment-intents).  
   - Implement an endpoint (e.g. Firebase Cloud Functions or your API) that:
     - Accepts `amount` (cents), `currency`, `orderId`.
     - Creates a PaymentIntent with Stripe’s server SDK.
     - Returns `{ "clientSecret": "pi_xxx_secret_xxx" }`.
   - Set this URL in `StripeService` (e.g. `baseURL = "https://your-api.com"`) and ensure the app calls `/create-payment-intent` (or match your route).

### 5. AI Cake Designer (optional)

- The **AI Cake Designer** uses an image-generation API. Set your backend URL in `AppConstants.imageGenerationBaseURL` (in **AppConstants.swift**).
- Your backend should accept `POST` with JSON `{"prompt": "..."}` and return either:
  - JSON `{"imageUrl": "https://..."}` or `{"imageBase64": "..."}`, or
  - Raw image bytes with `Content-Type: image/*`.
- You can use OpenAI DALL·E, Replicate, or your own model behind this endpoint.

### 6. Run the App

- Set a run destination (simulator or device).
- Build and run.  
- Use **Pay at Pickup** if you haven’t set up a Stripe backend yet.

### 7. Sample Data

- To seed sample bakery products, call once:
  ```swift
  Task { try? await SampleDataService.seedProductsIfNeeded() }
  ```
  You can trigger this from a temporary button or from Admin.

### 8. Admin Access

- In Firestore, set `users/<uid>.isAdmin = true` for the Firebase Auth UID you use to sign in.
- In the app, tap the **splash screen 5 times** to open Admin (add/edit products, mark sold out, view/update orders).

## Data Models

- **Product**: name, description, price, imageURL, category, isFeatured, isSoldOut.
- **CartItem**: product, quantity, specialInstructions; subtotal computed.
- **Order**: customerName, customerPhone, items (OrderItem), subtotal, tax, total, fulfillmentType, scheduledPickupDate, status, stripePaymentIntentId, estimatedReadyTime.
- **UserProfile**: uid, email, displayName, isAdmin.

## Cart & Order Logic

- **CartManager** (singleton): `add`, `updateQuantity`, `remove`, `clear`; exposes `items`, `subtotal`, `tax`, `total`, `toOrderItems()`.
- **CheckoutViewModel**: Builds `Order` from cart, calls `FirebaseService.createOrder`, then (for card/Apple Pay) `StripeService.presentPaymentSheet`; clears cart on success and navigates to Order Confirmation.

## Design

- Soft pastel palette, card-style product layout, rounded corners, light shadows.
- Colors and layout constants in `AppConstants.Colors` and `AppConstants.Layout`.

## Push Notifications

- **NotificationService** requests permission and registers for remote notifications; FCM token is available for your backend to send order-status updates.
- Configure APNs in Firebase (see FIREBASE_SETUP.md) and add Push Notifications capability in Xcode.

## Error Handling

- ViewModels set `errorMessage`; views show `ErrorMessageBanner` and allow dismiss.
- Network/Firebase/Stripe errors are surfaced to the user where appropriate.

## Production Checklist

- [ ] Restrict Firestore and Storage security rules (no test mode).
- [ ] Use a backend for Stripe PaymentIntents; never use secret key in the app.
- [ ] Add proper error handling and retries for payments.
- [ ] Enable and test push notifications with real APNs.
- [ ] Add unit/UI tests for cart and order flows.
- [ ] Set up CI (e.g. Xcode Cloud or Fastlane) and code signing for release.

## License

Use this project as you like; adjust branding and business logic for your bakery.
