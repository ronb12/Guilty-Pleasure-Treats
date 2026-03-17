# Backend: Firebase vs Vercel

## No Firebase project? The app still runs

The app is **written** to use Firebase (Auth, Firestore, Storage), but **it does not require a Firebase project to launch**. If you have not created a Firebase project or added **GoogleService-Info.plist**:

- The app **only configures Firebase** when that file is present in the project.
- **Products** come from built-in **sample data** (no Firestore).
- **Sign-in, orders, and saving data** will not work until you add a Firebase project and the plist; the app will show an error like "Firebase is not configured" if you try to place an order or sign in.

So: **no Firebase project = app runs with sample menu only.** Add Firebase when you want real auth, orders, and persistence.

---

## Current behavior (when Firebase is configured)

**The iOS app uses Firebase** for all backend features:

| Feature | Backend | Used by app |
|--------|---------|--------------|
| Auth (sign in, sign up, Sign in with Apple) | **Firebase Auth** | ✅ Yes |
| Products, orders, users, promotions, settings | **Firestore** | ✅ Yes |
| Product / cake images | **Firebase Storage** | ✅ Yes |
| Push notifications | **Firebase Cloud Messaging** | ✅ Yes |
| Stripe PaymentIntents | Your backend URL (`stripeBackendURLString`) | ✅ Called at checkout (replace with your Vercel or Cloud Function URL) |
| AI image generation | Your API URL (`imageGenerationBaseURL`) | ✅ Called by AI Cake Designer (replace with your endpoint) |

**The Vercel API** (in the repo under `api/`) is deployed and has routes like `/api/products` and `/api/orders`, but **the iOS app does not call it**. It’s there so you can later point the app at Vercel or use it for Stripe/web.

---

## Using Vercel instead of Firebase

To move data (products, orders) to Vercel:

1. **Set your Vercel base URL** in the app:  
   In `AppConstants.swift`, set `vercelBaseURLString` to your deployment (e.g. `https://guilty-pleasure-treats-xxx.vercel.app`).

2. **Backend mode**  
   The app can be extended to use **Vercel for products and orders** when `vercelBaseURLString` is set and a “use Vercel” flag is on. Right now the app still uses **Firebase only** for data; the Vercel API is separate.

3. **Auth**  
   If you use Vercel for data, you can keep **Firebase Auth** (current) or add auth via your Vercel API (e.g. JWT). The app today only uses Firebase Auth.

4. **Stripe**  
   You can host the Stripe “create PaymentIntent” logic on Vercel and set `stripeBackendURLString` to that Vercel URL (e.g. `https://your-app.vercel.app/api/create-payment-intent`).

---

## Summary

- **App today:** Firebase for auth, Firestore, Storage, push. Stripe and AI image URLs are configurable (can point to Vercel or anything else).
- **Vercel:** Deployed API exists; app does not use it for products/orders yet. You can point Stripe and AI image generation at Vercel by setting the URLs in `AppConstants`.

To have the app use **Vercel for products and orders**, the next step is to add a Vercel API client in the app and switch product/order calls from Firestore to that client when you want Vercel as the backend.
