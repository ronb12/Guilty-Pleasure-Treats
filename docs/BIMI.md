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

1. **Strong DMARC** — policy **`p=quarantine`** or **`p=reject`** (not only `p=none`), with alignment for your sending domain. Moving from `p=none` affects **all** mail that uses `@guiltypleasuretreats.com`; plan with your mail stack (Resend is aligned if SPF/DKIM pass for the From domain).
2. **Verified Mark Certificate (VMC)** — issued by an authorized CA, tied to a **registered trademark** that matches the logo in the SVG. You add the certificate URL in the BIMI record as the `a=` tag. This is **paid** and not something the repo can generate.
3. **Logo file** — must stay a **square**, **SVG** acceptable to BIMI; when you get a VMC, replace `website/bimi-logo.svg` with the **exact** artwork tied to that mark.

Until DMARC is enforced and a VMC is published, some providers may **not** show the inbox logo even though DNS is correct.

## Other providers

Yahoo, Fastmail, and others have their own BIMI support; the same DNS record and a valid logo help. Display is always **provider-dependent**.

## References

- [Google Workspace — Set up BIMI](https://support.google.com/a/answer/10911320) (requirements mirror consumer Gmail expectations for BIMI)
- [AuthIndicators / BIMI group](https://bimigroup.org/)
