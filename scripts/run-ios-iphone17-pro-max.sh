#!/usr/bin/env bash
# Build and launch "Guilty Pleasure Treats" on the iPhone 17 Pro Max simulator.
#
# Prerequisite: Xcode → Settings → Platforms → install the iOS Simulator runtime
# that matches your iPhone 17 Pro Max (e.g. iOS 26.x). If `simctl` shows the
# device as "(unavailable, runtime profile not found)", fix that first.
#
# Usage (from repo root):
#   bash scripts/run-ios-iphone17-pro-max.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ_DIR="$ROOT/Guilty Pleasure Treats"
PROJECT="$PROJ_DIR/Guilty Pleasure Treats.xcodeproj"
SCHEME="Guilty Pleasure Treats"
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro Max'
BUNDLE_ID='com.bradleyvirtualsolutions.Guilty-Pleasure-Treats'
DERIVED="$PROJ_DIR/build/DerivedData-ios"

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing Xcode project: $PROJECT"
  exit 1
fi

echo "== Checking iPhone 17 Pro Max simulator =="
if ! xcrun simctl list devices available 2>/dev/null | grep -q "iPhone 17 Pro Max"; then
  echo ""
  echo "No *available* iPhone 17 Pro Max simulator. Common fix:"
  echo "  Xcode → Settings → Platforms → download the iOS Simulator runtime for this device."
  echo "Then re-run this script."
  echo ""
  xcrun simctl list devices 2>/dev/null | grep -i "iPhone 17" || true
  exit 1
fi

echo "== Booting Simulator app + iPhone 17 Pro Max =="
open -a Simulator 2>/dev/null || true
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true

echo "== Building (Debug, iOS Simulator) =="
cd "$PROJ_DIR"
xcodebuild \
  -scheme "$SCHEME" \
  -project "Guilty Pleasure Treats.xcodeproj" \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Guilty Pleasure Treats.app"
if [[ ! -d "$APP" ]]; then
  echo "Build output not found at: $APP"
  exit 1
fi

echo "== Installing + launching =="
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"
echo "Done. App should appear on the booted simulator."
