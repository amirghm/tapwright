#!/usr/bin/env bash
# tapwright iOS Simulator helpers - source from workflow shell blocks.
# Usage:
#   export UDID=<simulator-udid>     # xcrun simctl list devices booted
#   source pack/scripts/ios-helpers.sh
# Requires: xcrun simctl; shrink-screenshot.sh alongside this file.
#
# Functions: screenshot
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _TAPWRIGHT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _TAPWRIGHT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  _TAPWRIGHT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Capture a full-res simulator screenshot then shrink it in place (writes <file>.meta).
screenshot() {
  xcrun simctl io "$UDID" screenshot "$1"
  "$_TAPWRIGHT_DIR/shrink-screenshot.sh" "$1"
}
