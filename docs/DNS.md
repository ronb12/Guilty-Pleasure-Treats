# DNS for `guiltypleasuretreats.com`

## Website (Vercel) — verified from public DNS

| Check | Status |
|--------|--------|
| Nameservers | `ns1.vercel-dns.com`, `ns2.vercel-dns.com` |
| Apex `A` | Points to Vercel anycast (e.g. `216.150.16.1`, `216.150.1.65`) |
| `www` | Points to Vercel; **HTTPS 307 → apex** (`https://guiltypleasuretreats.com/`) |
| `https://guiltypleasuretreats.com` | **200** from Vercel, HSTS present |

No change needed for the marketing site if Vercel shows the domain as **Valid Configuration**.

### Apex SPF + DMARC (recommended for `@guiltypleasuretreats.com` mail alignment)

| Record | Value |
|--------|--------|
| **TXT** at apex (`@`) | `v=spf1 include:amazonses.com ~all` |
| **TXT** at `_dmarc` | `v=DMARC1; p=none;` (trailing `;` matches Resend’s optional row) |

You can confirm with `dig TXT guiltypleasuretreats.com +short` and `dig TXT _dmarc.guiltypleasuretreats.com +short`.

---

## Email sending (Resend)

### Already added via Vercel CLI (typical US-East SES)

On the **`send`** subdomain:

- **MX** `10 feedback-smtp.us-east-1.amazonses.com`
- **TXT** `v=spf1 include:amazonses.com ~all`

If Resend still doesn’t verify **MX** (wrong region), replace the MX target with the exact host shown in **Resend → Domains** (e.g. `eu-west-1`).

**Vercel CLI (MX):** use hostname and priority as separate arguments, e.g.  
`vercel dns add guiltypleasuretreats.com '@' MX feedback-smtp.us-east-1.amazonses.com 10`

### Resend **Inbound** (Enable Receiving)

If you turn on **Receiving** for the root domain in Resend, add **apex** MX (name `@`):

- **MX** `10 inbound-smtp.us-east-1.amazonaws.com` (or the exact host Resend shows for your region)

Example:

```bash
vercel dns add guiltypleasuretreats.com '@' MX inbound-smtp.us-east-1.amazonaws.com 10
```

That record **captures all inbound mail** for `@guiltypleasuretreats.com` in Resend. Do **not** add it if you need Google Workspace or another host’s MX on the apex; use a **subdomain** for Resend receiving instead.

### DKIM (unique per domain — add last)

Your Vercel/production **`RESEND_API_KEY` is usually send-only**, so it cannot call `GET /domains` to read the DKIM string. Pick one path:

**A — One command (temporary full-access API key)**  
In Resend → API Keys, create a key with **full** permissions, then (same shell as `vercel login`):

```bash
RESEND_API_KEY=re_xxxxx_full_access ./scripts/sync-resend-dkim-vercel.sh
```

Revoke the full-access key after the record is created.

**B — Dashboard + CLI**

1. **Resend** → **Domains** → `guiltypleasuretreats.com` → copy the **TXT** value for **`resend._domainkey`**.
2. Run from the repo:

```bash
./scripts/add-resend-dkim-vercel.sh 'p=YOUR_FULL_VALUE_FROM_RESEND'
```

Or manually:

```bash
vercel dns add guiltypleasuretreats.com resend._domainkey TXT 'p=YOUR_FULL_VALUE_FROM_RESEND'
```

3. Click **Verify DNS Records** in Resend.

**Wildcard:** If `*` still resolves `send` to Vercel **A** records, that’s OK for mail — **MX/TXT on `send`** take precedence for those types.

**Optional:** DMARC TXT at `_dmarc` — Resend often shows `v=DMARC1; p=none;`.

---

## Receiving mail at `@guiltypleasuretreats.com` (e.g. Google Workspace)

Not required for **sending** newsletters via Resend. If you want **inboxes** like `info@…`, add the **MX** (and any verification TXT) your mail host provides. That is separate from Resend.

---

## Env after Resend verifies

- `NEWSLETTER_FROM_EMAIL` / `RESEND_FROM_EMAIL`: use an address on this domain, e.g. `newsletter@guiltypleasuretreats.com`.
- `NEWSLETTER_PUBLIC_BASE_URL`: e.g. `https://guiltypleasuretreats.com` (for unsubscribe links). See `docs/NOTIFICATIONS.md`.

---

## Re-check from terminal

```bash
dig NS guiltypleasuretreats.com +short
dig A guiltypleasuretreats.com +short
dig TXT guiltypleasuretreats.com +short
curl -sI https://guiltypleasuretreats.com | head -5
```
