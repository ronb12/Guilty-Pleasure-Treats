#!/usr/bin/env bash
# Add APNs env vars to Vercel. Run from repo root. You'll be prompted for each value.
# Requires: vercel CLI (npm i -g vercel) and Vercel project linked.
set -e
ENV="${1:-production}"
echo "Adding APNs environment variables to Vercel (environment: $ENV)."
echo "Have your APNs Key ID, Team ID, Bundle ID, and .p8 file contents ready."
echo ""
echo "APNS_KEY_ID (e.g. ABC123XYZ):"
vercel env add APNS_KEY_ID "$ENV"
echo "APNS_TEAM_ID (e.g. TFLP87PW54):"
vercel env add APNS_TEAM_ID "$ENV"
echo "APNS_BUNDLE_ID (e.g. com.bradleyvirtualsolutions.Guilty-Pleasure-Treats):"
vercel env add APNS_BUNDLE_ID "$ENV"
echo "APNS_SANDBOX (use 'true' for development builds, 'false' for production/TestFlight):"
vercel env add APNS_SANDBOX "$ENV"
echo "APNS_KEY_P8 (paste full .p8 file contents including BEGIN/END lines; press Enter then Ctrl+D when done):"
vercel env add APNS_KEY_P8 "$ENV"
echo "Done. Redeploy for changes to take effect."
echo "For a development environment run: $0 preview"
