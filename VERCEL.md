# Deploy Guilty Pleasure Treats API to Vercel

This repo includes a small **API** in the `api/` folder that you can deploy to Vercel. The iOS app can call these endpoints instead of (or alongside) Firebase.

## Deploy from GitHub

1. Go to [vercel.com](https://vercel.com) and sign in (GitHub login is easiest).
2. Click **Add New…** → **Project**.
3. **Import** the repo: `ronb12/Guilty-Pleasure-Treats`.
4. Vercel will detect the project. Leave **Root Directory** as `.` (repo root).
5. Click **Deploy**. No env vars are required for the placeholder API.
6. After deploy you’ll get a URL like `https://guilty-pleasure-treats-xxx.vercel.app`.

## API endpoints (after deploy)

| Endpoint        | Method | Description                |
|----------------|--------|----------------------------|
| `/api`         | GET    | API info and endpoint list |
| `/api/health`  | GET    | Health check               |
| `/api/products`| GET   | Placeholder product list   |
| `/api/orders`  | GET    | Placeholder order list     |
| `/api/orders`  | POST   | Placeholder create order   |

Example:

```bash
curl https://YOUR_VERCEL_URL.vercel.app/api/health
```

## Use in the iOS app

Set your Vercel base URL in the app (e.g. in `AppConstants` or a config file), then replace Firebase calls with `URLSession` requests to:

- `GET /api/products` for the menu
- `POST /api/orders` for placing orders (add auth and validation later)

## Next steps

- Add a database (e.g. [Vercel Postgres](https://vercel.com/storage/postgres)) and wire `api/products.js` and `api/orders.js` to it.
- Add auth (e.g. JWT or a provider like Clerk/Auth0) and protect `/api/orders`.
- Add env vars in the Vercel dashboard (e.g. `DATABASE_URL`, `STRIPE_SECRET_KEY`) and use them in the `api/*.js` functions.
