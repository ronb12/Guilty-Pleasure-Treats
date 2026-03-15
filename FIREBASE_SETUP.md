# Firebase Setup Instructions

Follow these steps to connect **Guilty Pleasure Treats** to your Firebase project.

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (or use an existing project).
3. Enable **Google Analytics** if desired (optional).
4. Finish creating the project.

## 2. Add an iOS App

1. In the project overview, click the **iOS** icon to add an iOS app.
2. Enter your app’s **Bundle ID** (e.g. `com.yourcompany.GuiltyPleasureTreats`). It must match the Bundle Identifier in Xcode.
3. Optionally add App Nickname and App Store ID.
4. Click **Register app**.
5. Download **GoogleService-Info.plist** and add it to your Xcode project (drag into the app target, ensure “Copy items if needed” is checked).

## 3. Enable Authentication

1. In Firebase Console, go to **Build → Authentication**.
2. Click **Get started**.
3. Open the **Sign-in method** tab.
4. Enable **Email/Password** (and optionally **Anonymous** for guest checkout).

## 4. Create Firestore Database

1. Go to **Build → Firestore Database**.
2. Click **Create database**.
3. Choose **Start in test mode** for development (restrict rules before production).
4. Pick a location and enable.

### Firestore Security Rules (development)

Use these for local/testing; tighten for production:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /orders/{orderId} {
      allow read: if request.auth != null;
      allow create: if true;
      allow update, delete: if request.auth != null;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Firestore Indexes

If you use composite queries (e.g. orders by `userId` and `createdAt`), create the index when Firestore prompts you via the error link in the console.

## 5. Firebase Storage

1. Go to **Build → Storage**.
2. Click **Get started**.
3. Use **test mode** for development (restrict before production).
4. Choose a location.

### Storage Rules (development)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /products/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 6. Add Firebase SDK via Swift Package Manager

1. In Xcode: **File → Add Package Dependencies…**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Add these products to your app target:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - **FirebaseStorage**
   - **FirebaseMessaging** (for push notifications)

## 7. Initialize Firebase in the App

In `GuiltyPleasureTreatsApp.swift`, `FirebaseApp.configure()` is already called from `AppDelegate`. Ensure `GoogleService-Info.plist` is in the app target so Firebase can load configuration.

## 8. Push Notifications (optional)

1. In Firebase Console: **Project Settings → Cloud Messaging**.
2. Upload your **APNs Authentication Key** or **APNs Certificate** (from Apple Developer).
3. In Xcode: **Signing & Capabilities → + Capability → Push Notifications**.
4. Enable **Background Modes → Remote notifications** if you want background handling.

## 9. Admin Users

To mark a user as admin:

1. In Firestore, create or edit a document in the **users** collection.
2. Document ID = the user’s Firebase Auth **UID**.
3. Set field `isAdmin: true`.

The app uses this to show the hidden Admin section (5 taps on splash) and to allow editing products and order status.

## 10. Seed Sample Products (optional)

To preload sample bakery items, call once (e.g. from a dev button or at first launch):

```swift
Task {
    try? await SampleDataService.seedProductsIfNeeded()
}
```

You can add a temporary button in Admin or in a debug menu that runs this.
