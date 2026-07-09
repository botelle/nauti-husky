#!/usr/bin/env bash
# scripts/build-testflight.sh — archive -> export -> upload Nauti Husky (iOS) to TestFlight.
#
# Runs on the Studio (stable Xcode, headless build keychain, Admin App Store
# Connect API key). Account creds come from ~/agent/.testflight.env — the same
# app-agnostic config the loyalty pipeline uses (ASC_KEY_ID/ISSUER/KEY_PATH,
# TEAM_ID, KEYCHAIN, KEYCHAIN_PASS). Ships under the HuskySwimTime App Store
# Connect record (bundle id org.botelle.SwimTime); build numbers auto-increment
# on Apple's side (manageAppVersionAndBuildNumber).
#
# Usage (from a checkout):  bash scripts/build-testflight.sh
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

CFG="${TESTFLIGHT_ENV:-$HOME/agent/.testflight.env}"
[[ -f "$CFG" ]] || { echo "FATAL: missing config $CFG (see reference-ios-testflight)"; exit 1; }
# shellcheck disable=SC1090
source "$CFG"
: "${ASC_KEY_ID:?}"; : "${ASC_ISSUER:?}"; : "${ASC_KEY_PATH:?}"
: "${TEAM_ID:?}"; : "${KEYCHAIN:?}"; : "${KEYCHAIN_PASS:?}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-NautiHuskyTemp-iOS}"
PROJECT="${PROJECT:-NautiHuskyTemp.xcodeproj}"
WORK="${WORK:-/tmp/nh-tf-build}"
ARCHIVE="$WORK/app.xcarchive"
EXPORT_DIR="$WORK/export"
rm -rf "$WORK"; mkdir -p "$WORK"

echo "==> [1/4] generating project (xcodegen)"
xcodegen generate

echo "==> unlocking build keychain ($KEYCHAIN)"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
PREV_DEFAULT="$(security default-keychain | tr -d ' "')"
security default-keychain -s "$KEYCHAIN"
trap 'security default-keychain -s "$PREV_DEFAULT" >/dev/null 2>&1 || true' EXIT

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER")

echo "==> [2/4] archiving $SCHEME"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
    "${AUTH[@]}" DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic archive

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

echo "==> [3/4] exporting (distribution re-sign)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" "${AUTH[@]}"

IPA="$(ls "$EXPORT_DIR"/*.ipa | head -1)"
echo "==> [4/4] uploading $(basename "$IPA") to TestFlight"
xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER"

echo "==> DONE: uploaded $(basename "$IPA") for scheme $SCHEME"
