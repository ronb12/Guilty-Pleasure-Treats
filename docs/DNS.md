# DNS for `guiltypleasuretreats.com`

## Website (Vercel) — verified from public DNS

| Check | Status |
|--------|--------|
| Nameservers | `ns1.vercel-dns.com`, `ns2.vercel-dns.com` |
| Apex `A` | Points to Vercel anycast (e.g. `216.150.16.1`, `216.150.1.65`) |
| `www` | Points to Vercel; **HTTPS 307 → apex** (`https://guiltypleasuretreats.com/`) |
| `https://guiltypleasuretreats.com` | **200** from Vercel, HSTS present |

No change needed for the marketing site if Vercel shows the domain as **Valid Configuration**.

---

## Email sending (Resend)

### Already added via Vercel CLI (typical US-East SES)

On the **`send`** subdomain:

- **MX** `10 feedback-smtp.us-east-1.amazonses.com`
- **TXT** `v=spf1 include:amazonses.com ~all`

If Resend still doesn’t verify **MX** (wrong region), replace the MX target with the exact host shown in **Resend → Domains** (e.g. `eu-west-1`).

### DKIM (you must finish — unique per domain)

1. **Resend** → **Domains** → `guiltypleasuretreats.com` → copy the **TXT** value for **`resend._domainkey`**.
2. Run from the repo (same machine as `vercel login`):

```bash
./scripts/add-resend-dkim-vercel.sh 'p=YOUR_FULL_VALUE_FROM_RESEND'
```

Or manually:

```bash
vercel dns add guiltypleasuretreats.com resend._domainkey TXT 'p=YOUR_FULL_VALUE_FROM_RESEND'
```

3. Click **Verify DNS Records** in Resend.

**Note:** A **full-access** Resend API key can list domain DNS via their API; typical **send-only** keys cannot — use the dashboard for the DKIM string.

**Wildcard:** If `*` still resolves `send` to Vercel **A** records, that’s OK for mail — **MX/TXT on `send`** take precedence for those types.

**Optional (after verify):** DMARC TXT at `_dmarc` — Resend’s dashboard has guidance.

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
