#!/usr/bin/env bash
# Fetch DKIM TXT from Resend (GET /domains) and add resend._domainkey on Vercel DNS.
# Requires a Resend API key with domain read access (not "send emails only").
# Usage:
#   RESEND_API_KEY=re_xxx_full_access ./scripts/sync-resend-dkim-vercel.sh
# Optional: DOMAIN=other.com RESEND_API_KEY=re_xxx ./scripts/sync-resend-dkim-vercel.sh

set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN="${DOMAIN:-guiltypleasuretreats.com}"
KEY="${RESEND_API_KEY:?Set RESEND_API_KEY (full access — send-only keys return 401 on /domains)}"

if vercel dns ls "$DOMAIN" 2>/dev/null | grep -qF 'resend._domainkey'; then
  echo "Vercel DNS already has resend._domainkey — nothing to add."
  exit 0
fi

list_json="$(curl -sS -H "Authorization: Bearer ${KEY}" "https://api.resend.com/domains")"
if echo "$list_json" | jq -e '.statusCode' >/dev/null 2>&1; then
  echo "Resend API: $(echo "$list_json" | jq -r '.message // .')" >&2
  echo "Create a temporary key with full permissions in Resend → API Keys, run this script, then revoke it." >&2
  exit 1
fi

domain_id="$(echo "$list_json" | jq -r --arg d "$DOMAIN" '.data[] | select(.name == $d) | .id' | head -1)"
if [[ -z "$domain_id" || "$domain_id" == null ]]; then
  echo "No domain \"$DOMAIN\" in your Resend account ($(echo "$list_json" | jq -r '.data[].name' | tr '\n' ' '))." >&2
  exit 1
fi

detail_json="$(curl -sS -H "Authorization: Bearer ${KEY}" "https://api.resend.com/domains/${domain_id}")"
if echo "$detail_json" | jq -e '.statusCode' >/dev/null 2>&1; then
  echo "Resend API: $(echo "$detail_json" | jq -r '.message // .')" >&2
  exit 1
fi

dkim_val="$(echo "$detail_json" | jq -r '.records[]? | select(.record == "DKIM") | .value' | head -1)"
dkim_val="${dkim_val//\"/}"
if [[ -z "$dkim_val" || "$dkim_val" == null ]]; then
  echo "No DKIM record in Resend response for $DOMAIN." >&2
  exit 1
fi

if [[ "$dkim_val" != p=* ]]; then
  echo "Unexpected DKIM value (expected p=...): ${dkim_val:0:40}..." >&2
  exit 1
fi

vercel dns add "$DOMAIN" resend._domainkey TXT "$dkim_val"
echo "Done. In Resend → Domains → $DOMAIN → Verify DNS Records."
