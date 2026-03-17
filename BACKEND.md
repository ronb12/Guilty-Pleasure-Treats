# Backend: Firebase vs Vercel

## No Firebase project? The app still runs

The app is **written** to use Firebase (Auth, Firestore, Storage), but **it does not require a Firebase project to launch**. If you have not created a Firebase project or added **GoogleService-Info.plist**:

- The app **only configures Firebase** when that file is present in the project.
- **Products** come from built-in **sample data** (no Firestore).
- **Sign-in, orders, and saving data** will not work until you add a Firebase project and the plist; the app will show an error like "Firebase is not configured" if you try to place an order or sign in.

So: **no Firebase project = app runs with sample menu only.** Add Firebase when you want real auth, orders, and persistence.

---

## Using Vercel for data (recommended)

You can use **Vercel** for products, orders, and image storage instead of (or without) Firebase.

### 1. Deploy the API and add storage

1. **Deploy** this repo to [Vercel](https://vercel.com) (connect the Git repo or run `vercel` in the project root).
2. **Neon Postgres:** In Vercel → Project → Storage → Create Database → **Neon**. This sets `POSTGRES_URL` for your project.
3. **Run the schema once:** In Neon’s SQL tab (or Vercel’s Neon dashboard), run the SQL in **`api/schema.sql`** to create `products` and `orders` tables.
4. **Vercel Blob (optional, for images):** In Vercel → Storage → Create → **Blob**. This sets `BLOB_READ_WRITE_TOKEN`. If you skip Blob, product image upload from the app will fail until you add it.

### 2. Point the app at Vercel

In **`Guilty Pleasure Treats/Utilities/AppConstants.swift`**, set:

```swift
static let vercelBaseURLString: String? = "https://your-deployment.vercel.app"
```

Use your real Vercel URL (no trailing slash). When this is set:

- **Products** are loaded from the Vercel API (Neon).
- **Orders** are created and listed via the Vercel API (Neon).
- **Product image uploads** go to Vercel Blob via `/api/upload`.
- **Admin** order actions (status, mark paid, estimated ready) use the Vercel API.

Auth, user profiles, business settings, and promotions still use **Firebase** when Firebase is configured; otherwise those features are unavailable or use in-memory/sample data.

### 3. Summary

| Feature              | When `vercelBaseURLString` is set | When not set (and Firebase configured) |
|----------------------|------------------------------------|----------------------------------------|
| Products             | Vercel API (Neon)                  | Firestore                               |
| Orders               | Vercel API (Neon)                  | Firestore                               |
| Product image upload | Vercel Blob                        | Firebase Storage                         |
| Auth                 | Firebase (if configured)           | Firebase (if configured)                 |
| User profile, settings, promotions | Firebase (if configured) | Firestore                               |

---

## Current behavior (when Firebase is configured and Vercel is not)

**The iOS app uses Firebase** for all backend features when `vercelBaseURLString` is nil:

| Feature | Backend | Used by app |
|--------|---------|-------------|
| Auth (sign in, sign up, Sign in with Apple) | **Firebase Auth** | ✅ Yes |
| Products, orders, users, promotions, settings | **Firestore** | ✅ Yes |
| Product / cake images | **Firebase Storage** | ✅ Yes |
| Push notifications | **Firebase Cloud Messaging** | ✅ Yes |
| Stripe PaymentIntents | Your backend URL (`stripeBackendURLString`) | ✅ Called at checkout |
| AI image generation | Your API URL (`imageGenerationBaseURL`) | ✅ Called by AI Cake Designer |

---

## Vercel API routes

| Route | Method | Description |
|-------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/products` | GET | List products (query: `category`, `featured`) |
| `/api/products/[id]` | GET | Single product |
| `/api/orders` | GET | List orders (query: `userId` for my orders) |
| `/api/orders` | POST | Create order (JSON body) |
| `/api/orders/[id]` | GET / PATCH | Get or update order (PATCH: `status`, `manualPaidAt`, `estimatedReadyTime`) |
| `/api/upload` | POST | Upload image (JSON: `base64`, optional `pathname`, `contentType`); returns `{ url }` |
| `/api/ai/generate-image` | POST | AI Cake Designer: body `{ "prompt": "..." }` → image bytes (free, Pollinations.ai) or `{ "imageUrl": "..." }` if **OPENAI_API_KEY** is set (DALL-E 3). No API key required for free tier. |

Without a Neon database connected, `/api/products` and `/api/orders` return placeholder or empty data. Without Blob, `/api/upload` returns 503.
