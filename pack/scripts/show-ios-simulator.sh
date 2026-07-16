#!/usr/bin/env bash
# Bring a specific iOS Simulator to the foreground for visible /test or /exec runs.
# Usage: show-ios-simulator.sh <UDID>
set -euo pipefail

UDID="${1:?Usage: show-ios-simulator.sh <UDID>}"

echo "Shutting down other booted simulators..."
while IFS= read -r other; do
  [[ -z "$other" || "$other" == "$UDID" ]] && continue
  echo "  shutdown $other"
  xcrun simctl shutdown "$other" 2>/dev/null || true
done < <(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' || true)

echo "Booting $UDID..."
xcrun simctl boot "$UDID" 2>/dev/null || true
defaults write com.apple.iphonesimulator CurrentDeviceUDID "$UDID"

echo "Opening Simulator.app..."
open -a Simulator
osascript -e 'tell application "Simulator" to activate'
sleep 2
xcrun simctl bootstatus "$UDID" -b

echo "Ready - Simulator should be visible for UDID $UDID"
echo "If you still do not see it, click Simulator in the Dock."
