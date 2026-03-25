# BIMI (inbox logo next to your emails)

**BIMI** (Brand Indicators for Message Identification) is what allows mailbox providers to show your **logo** in the sender slot (e.g. Gmail’s circular avatar), separate from the `<img>` in the message body.

## What we host in this repo

- **`website/bimi-logo.svg`** — SVG Tiny PS–style mark (brand pink `#E84294`), served at  
  **`https://guiltypleasuretreats.com/bimi-logo.svg`** after deploy (same static site as `/app-icon.png`).

## DNS (Vercel)

Publish a **TXT** record at **`default._bimi`** (subdomain `default._bimi`, not `@`):

```text
v=BIMI1; l=https://guiltypleasuretreats.com/bimi-logo.svg;
```

Optional **after** you obtain a certificate (see below):

```text
v=BIMI1; l=https://guiltypleasuretreats.com/bimi-logo.svg; a=https://guiltypleasuretreats.com/path-to-vmc.pem;
```

**Vercel CLI example:**

```bash
vercel dns add guiltypleasuretreats.com 'default._bimi' TXT 'v=BIMI1; l=https://guiltypleasuretreats.com/bimi-logo.svg;'
```

Verify:

```bash
dig TXT default._bimi.guiltypleasuretreats.com +short
curl -sI https://guiltypleasuretreats.com/bimi-logo.svg | head -3
```

## Gmail — what you still need for the logo to appear

Google generally expects:

1. **Strong DMARC** — policy **`p=quarantine`** or **`p=reject`** (required for typical Gmail BIMI avatar). The domain currently uses **`p=none`** with **`rua=`** so you can **review aggregate reports** first; only move to **`p=quarantine`** when reports show **consistent SPF/DKIM pass and alignment** for all mail from `@guiltypleasuretreats.com` (Resend + anything else), or Gmail may filter newsletters.
2. **Verified Mark Certificate (VMC)** — issued by an authorized CA (e.g. DigiCert, Entrust), tied to a **registered trademark** matching the SVG. You **cannot** generate this in-repo; purchase the VMC, host the **`.pem`** file over **HTTPS** with the **Content-Type** your CA specifies, then add it to BIMI as **`a=`**.
3. **Logo file** — square **SVG** tied to that trademark; replace **`website/bimi-logo.svg`** with the **exact** artwork from the VMC package when your CA provides it.

### After you have the VMC PEM URL

1. Delete the existing **`default._bimi`** TXT in Vercel DNS (or your DNS UI), then add one line that includes **both** `l=` and **`a=`**:

```text
v=BIMI1; l=https://guiltypleasuretreats.com/bimi-logo.svg; a=https://guiltypleasuretreats.com/vmc.pem;
```

2. Replace **`a=`** with your real public HTTPS URL to the PEM. Redeploy if you add the file under **`website/`**.

Without a valid **`a=`** and CA-issued PEM, Gmail will typically **not** show the inbox avatar, even with DMARC enforced.

## Other providers

Yahoo, Fastmail, and others have their own BIMI support; the same DNS record and a valid logo help. Display is always **provider-dependent**.

## References

- [Google Workspace — Set up BIMI](https://support.google.com/a/answer/10911320) (requirements mirror consumer Gmail expectations for BIMI)
- [AuthIndicators / BIMI group](https://bimigroup.org/)
