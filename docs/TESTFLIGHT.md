# TestFlight setup with Fastlane

This project uses **Fastlane** to build the iOS app and upload it to **App Store Connect** for **TestFlight** beta testing.

## Prerequisites

- **Apple Developer account** (enrolled in App Store Connect)
- **Xcode** with valid code signing (Automatic or manual provisioning)
- App **Guilty Pleasure Treats** created in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats`

## 1. Install Fastlane

From the project root (same folder as `Gemfile`):

```bash
bundle install
```

If you don’t have Bundler: `gem install bundler` then `bundle install`.

## 2. App Store Connect API Key (recommended)

Using an **App Store Connect API Key** avoids 2FA prompts and works well in CI.

1. In [App Store Connect](https://appstoreconnect.apple.com) go to **Users and Access** → **Integrations** → **App Store Connect API**.
2. Create a new key with **App Manager** or **Admin** role; download the `.p8` file once (you can’t download it again).
3. Note:
   - **Key ID** (e.g. `D83848D23`)
   - **Issuer ID** (top of the API keys page, e.g. `227b0bbf-ada8-458c-9d62-3d8022b7d07f`)
4. In the project, create `fastlane/AppStoreConnectApiKey.json` (this file is gitignored):

```json
{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "key_filepath": "/absolute/path/to/YourKey.p8"
}
```

Use the real path to your `.p8` file (e.g. in your home folder or in `fastlane/`).

Alternatively you can use environment variables instead of the file:

- `APP_STORE_CONNECT_API_KEY_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` (path to the `.p8` file)

## 3. Share the Xcode scheme (if needed)

If Fastlane can’t find the scheme, in Xcode: **Product** → **Scheme** → **Manage Schemes**, select **Guilty Pleasure Treats**, check **Shared**, and save. The scheme will be stored in the repo so `fastlane beta` can use it.

## 4. Code signing

- **Automatic:** In Xcode, leave “Automatically manage signing” on and select your Team. Fastlane will use the same setup.
- **Manual / Match:** If you use [fastlane match](https://docs.fastlane.tools/actions/match/), run `match` before the `beta` lane and ensure the scheme uses the correct provisioning profile.

## 5. Upload to TestFlight

From the project root:

```bash
bundle exec fastlane beta
```

This will:

1. Build the app (scheme **Guilty Pleasure Treats**, export for App Store).
2. Upload the resulting IPA to App Store Connect for TestFlight.
3. Skip waiting for “build processing” so the command returns after upload (processing continues on Apple’s side).

After processing (usually 5–15 minutes), the build will appear in **App Store Connect** → your app → **TestFlight**. Add internal/external testers and enable the build for testing.

## 6. Build only (no upload)

To build the IPA without uploading:

```bash
bundle exec fastlane build
```

Output is in `./build/GuiltyPleasureTreats.ipa`.

## 7. Optional: bump build number

To auto-increment the build number before each upload, uncomment this line in `fastlane/Fastfile` (inside the `beta` lane):

```ruby
increment_build_number(xcodeproj: project_path)
```

## Troubleshooting

- **“Missing package product 'StripePaymentSheet'”**  
  Resolve the Swift package in Xcode (File → Packages → Resolve Package Versions) and ensure the scheme builds in Xcode before running Fastlane.

- **Code signing errors**  
  Open the project in Xcode, select the **Guilty Pleasure Treats** target, **Signing & Capabilities**, and confirm Team and provisioning are correct. Run `bundle exec fastlane build` and fix any signing errors shown.

- **“Could not find app with identifier”**  
  Create the app in App Store Connect with bundle ID `com.bradleyvirtualsolutions.Guilty-Pleasure-Treats` and try again.

- **Apple ID / 2FA prompt**  
  If you didn’t set up the API key, Fastlane will ask for your Apple ID and (if needed) an app-specific password. Prefer the API key for a non-interactive flow.
