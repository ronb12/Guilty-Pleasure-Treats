#!/usr/bin/env bash
# Add Resend DKIM TXT to Vercel DNS (dkim value is unique per domain — copy from Resend dashboard).
# Usage:
#   ./scripts/add-resend-dkim-vercel.sh 'p=MIGfMA0GCS...long...'
# Or paste only the value Resend shows for resend._domainkey (often starts with p=).

set -euo pipefail
cd "$(dirname "$0")/.."

VAL="${1:?Usage: $0 '<DKIM TXT value from Resend (resend._domainkey)>'}"

if [[ "$VAL" != p=* ]]; then
  echo "Warning: DKIM values usually start with p= — check your Resend dashboard copy." >&2
fi

vercel dns add guiltypleasuretreats.com resend._domainkey TXT "$VAL"

echo "Done. In Resend → Domains → guiltypleasuretreats.com → Verify DNS Records."
