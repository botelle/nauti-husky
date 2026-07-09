#!/usr/bin/env bash
# Boots an iOS simulator, builds + installs the app, launches it, and captures a
# screenshot. This is the foundation for agent-driven "driving" of the app: an
# agent can boot the sim, launch, screenshot, and (later) inspect/tap via simctl.
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

DEVICE="${SIM_DEVICE:-iPhone 17}"
BUNDLE_ID="net.botelle.NautiHuskyTemp"
SCHEME="NautiHuskyTemp-iOS"
OUT="${OUT_DIR:-artifacts}"
mkdir -p "$OUT"

echo "==> Generating project (XcodeGen)"
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate

echo "==> Building $SCHEME for the simulator"
xcodebuild build \
  -project NautiHuskyTemp.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO >/dev/null

APP_PATH="$(find build/Build/Products -name '*.app' -path '*iphonesimulator*' | head -1)"
echo "==> App bundle: $APP_PATH"

echo "==> Booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
# Pre-grant location so the app runs without the permission prompt.
xcrun simctl privacy "$DEVICE" grant location "$BUNDLE_ID" 2>/dev/null || true

echo "==> Installing + launching (demo mode for deterministic content)"
xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -UITestDemo
sleep 6

echo "==> Capturing screenshot"
xcrun simctl io "$DEVICE" screenshot "$OUT/launch.png"
ls -l "$OUT/launch.png"
echo "==> Smoke complete: $OUT/launch.png"
