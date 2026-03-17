# App Store readiness checklist

Use this when submitting **Guilty Pleasure Treats** to the App Store. Complete each item in App Store Connect (and optionally in the app) so review goes smoothly.

---

## 1. Required URLs (App Store Connect)

In **App Store Connect → Your App → App Information** (and in the version submission page):

| Field | What to set | Notes |
|-------|----------------------|--------|
| **Privacy Policy URL** | A live webpage URL for your privacy policy | Required. Use `AppConstants.privacyPolicyURLString` or host the same content you show in-app (e.g. `LegalContent.privacyPolicyMarkdown`). |
| **Support URL** | A live webpage or contact page | Required. Use `AppConstants.supportURLString` or a dedicated support/contact page. |

Update `AppConstants.swift` with your real URLs before submission so in-app links (e.g. Settings) match.

---

## 2. App constants (in Xcode)

In **AppConstants.swift** confirm or set:

- `privacyPolicyURLString` — must point to a real, public URL (e.g. your site’s privacy page).
- `supportURLString` — must point to a real support or contact URL.
- `ownerEmails` — add the bakery owner’s email(s) so they get admin access.
- `contactEmailString` — business email shown in Settings/Contact.

---

## 3. App Store Connect – version details

- **Screenshots**: At least one screenshot per required device size (e.g. 6.7", 6.5", 5.5"). Show Home, Menu, Cart, or Gallery.
- **Description**: Short description of the app (e.g. order treats, view gallery, custom cakes).
- **Keywords**: Terms for search (e.g. bakery, cakes, cookies, order, custom cake).
- **Category**: e.g. Food & Drink.
- **Age rating**: Complete the questionnaire (likely 4+ if no restricted content).

---

## 4. Build and compliance

- **Signing**: Use a valid Apple Developer account and distribution certificate.
- **Capabilities**: Sign in with Apple is configured (entitlement + backend).
- **No test/placeholder data in production**: Ensure menu, gallery, and business info are real or clearly placeholder as intended.

---

## 5. After submission

- **Review notes** (if needed): Explain test account, demo mode, or backend URL if reviewers need to test.
- **Contact**: Ensure the contact email in App Store Connect is monitored so you can respond to review questions.

---

*Quick reference: Privacy Policy URL and Support URL are required by Apple and must be valid before you submit for review.*
