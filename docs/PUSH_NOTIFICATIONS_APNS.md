# Push Notifications (APNs, no Firebase)

Push uses **Apple Push Notification service (APNs)** from the Vercel backend—no Firebase.

- **Admin**: "New order" when a customer places an order; "New message" when someone submits the contact form.
- **Customer**: Order status updates (e.g. "Your order is ready for pickup").

## Flow

1. **iOS app**: When any user signs in (admin or customer), the app registers for remote notifications, gets an APNs device token, and sends it to `POST /api/push/register`. The backend stores it in `push_tokens` with `is_admin` from the session.
2. **New order**: `POST /api/orders` sends a push to all tokens where `is_admin = true` (title "New order", body e.g. "Customer Name – $25.00").
3. **Order status**: When admin updates status, the backend sends a push to the customer’s token (title "Order update", body with status).
4. **New message**: When the contact form is submitted, the backend sends a push to admin tokens (title "New message").

## 1. Apple Developer setup

1. In [Apple Developer](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Keys**, create a new key and enable **Apple Push Notifications service (APNs)**. Download the `.p8` file (you can only download it once). Note the **Key ID**.
2. Note your **Team ID** (in the top-right or Membership details) and your app’s **Bundle ID** (e.g. `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`).
3. In Xcode, ensure the app target has the **Push Notifications** capability (Signing & Capabilities). This project already has it: `Guilty Pleasure Treats/Guilty_Pleasure_Treats.entitlements` contains `aps-environment` (use `development` for dev builds, `production` for App Store).

## 2. Vercel environment variables

**Option A – script (prompts for each value):** From the repo root, run:

```bash
./scripts/setup-vercel-apns-env.sh production
```

Use `./scripts/setup-vercel-apns-env.sh preview` for the preview environment. Have your Key ID, Team ID, Bundle ID, and full `.p8` file contents ready.

**Option B – manual:** In the Vercel project → **Settings** → **Environment Variables**, add:

| Variable        | Description |
|-----------------|-------------|
| `APNS_KEY_ID`   | Key ID of the APNs key (e.g. `ABC123XYZ`) |
| `APNS_TEAM_ID`  | Apple Team ID (e.g. `TFLP87PW54`) |
| `APNS_BUNDLE_ID`| App bundle ID (e.g. `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`) |
| `APNS_KEY_P8`   | **Full contents** of the `.p8` file (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`) |
| `APNS_SANDBOX`  | Set to `true` only for development/sandbox; leave unset or `false` for production |

Paste the entire `.p8` file into `APNS_KEY_P8` (multi-line is fine).

## 3. Database

The `push_tokens` table must exist. Run once (e.g. with Neon connected):

```bash
node --env-file=.env.neon scripts/run-push-tokens-schema.js
```

Or run the SQL in `api/push-tokens-schema.sql` in the Neon SQL Editor.

## 4. Testing

Use a **real device** (push does not work in Simulator).

- **New order (admin)**  
  1. Sign in as admin, open Admin (token registers).  
  2. Place an order from another device or test checkout.  
  3. Admin device should get **"New order"** with customer name and total.

- **Order status (customer)**  
  1. Sign in as a customer and place an order (token registers on sign-in).  
  2. As admin, change the order status (e.g. to "Ready for pickup").  
  3. Customer device should get **"Order update"** with the new status.

- **New message (admin)**  
  1. Submit the contact form (web or app).  
  2. Admin device should get **"New message"**.

For **development** builds use `APNS_SANDBOX=true`. For **App Store / TestFlight** use production (unset `APNS_SANDBOX` or set to `false`).
