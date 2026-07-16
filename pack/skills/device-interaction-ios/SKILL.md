---
name: Device Interaction (iOS simulator)
description: |
  Reusable iOS Simulator control skill built on `simctl` + `idb`. Use this skill whenever:
  - `/test SPEC --ios` needs to drive a simulator (visible by default; `--headless` for background).
  - `/exec ... on ios ...` needs to drive a simulator from a natural-language task.
  - You need to tap, swipe, screenshot, or dump the accessibility tree on an iOS Simulator.
  - You need to discover, boot, or choose between booted simulators.
  Android adb: the device-interaction skill.
  App-specific values (bundle_id, scheme, build command) come from `tapwright.config.yml`.
---

# Device Interaction (iOS via `simctl` + `idb`)

A thin, copy-pasteable layer for driving an iOS Simulator. The agent runs these commands with the Shell tool.

**Config:** read `tapwright.config.yml` for `ios.bundle_id`, `ios.scheme`, `ios.config`, and `ios.build`. Examples below use `com.example.app` - substitute the config values.

## Prerequisites

Install once on the dev Mac:

```bash
brew tap facebook/fb
brew install idb-companion
pip3 install fb-idb    # or: pipx install fb-idb
```

Verify:

```bash
which idb && idb --help | head -3
xcodebuild -version
```

**Xcode** + at least one **iOS Simulator runtime** must be installed.

## Golden rules

1. **Simulators only by default.** Physical iOS devices require explicit user confirmation.
2. **Prefer booted simulators.** Boot one if none are running (see below).
3. **Disambiguate multiples.** If more than one simulator is booted, ask the user which UDID to use.
4. **Respect visibility mode** - default visible on `--ios`; `--headless` for background (see below).
5. **Start idb companion** for the target UDID before `idb ui` commands (see Troubleshooting).
6. **Batch for speed** in `--headless` mode. Visible default: one step per Shell call with longer pauses.
7. **Resolve from accessibility tree before tapping.** `idb ui describe-all` → grep `AXLabel` / frame → tap. VLM only when the tree lacks what you need or after 2 failed taps.
8. **Helpers.** `source pack/scripts/ios-helpers.sh` - `screenshot` (auto-shrinks to max long-edge 540).
9. **Taps from AX, not PNG.** Checkpoint screenshots are shrunk for VLM/reports; never derive tap coords from the shrunk image when AX frames exist.
10. **No Python orchestration scripts.**

## Simulator visibility (default visible, `--headless` optional)

Controlled by `/test` / `/exec` flags. Record as `meta.simulator_visibility` in DSL and reports.

| Mode | Flag | What happens |
|---|---|---|
| **Visible** (default) | `--ios` (no extra flag) | Like an Android emulator window: **Simulator.app opens**, device brought forward, slower pauses so you can watch. |
| **Headless** | `--ios --headless` | `simctl` + `idb` only - **do not** open Simulator.app. Fast batched taps; CI-style. |

### Visible setup (default for `--ios`)

**When not `--headless`:** open Simulator so the user can watch - same intent as seeing the Android emulator.

**Critical:** Do **not** batch the full task in one Shell call. The user must see Simulator move between steps - run **one UI action per Shell invocation** (or small group), narrate each step in chat, and use **5s+ pauses**. The `show-ios-simulator.sh` helper handles boot + focus:

```bash
export UDID="<target-udid>"
export BUNDLE_ID="com.example.app"          # from tapwright.config.yml
pack/scripts/show-ios-simulator.sh "$UDID"  # shuts down other sims, boots, focuses Simulator.app
```

Then per step: `idb companion` (once) → launch → tap → `sleep 5` → next tap. Tell the user in chat before the first tap.

### Headless setup (`--headless`)

```bash
# Boot if needed - do NOT open Simulator.app
xcrun simctl boot "$UDID" 2>/dev/null || true
# Short pauses: 0.3-1s tap-to-tap; 3-5s after launch; batch taps in one Shell call
```

| Setting | Visible (default) | `--headless` |
|---|---|---|
| `open -a Simulator` | **yes** + `osascript activate` | **no** |
| Other booted sims | **shutdown** (keep one) | any |
| Pauses | **3-5s** between taps | 0.3-1s |
| Shell batching | one step per call | may batch 2-5 steps |

**Limitation:** an agent shell cannot force window z-order without macOS Accessibility permission. `osascript -e 'tell application "Simulator" to activate'` usually suffices; if the user still does not see it, ask them to click **Simulator** in the Dock once, then continue.

## Setup: target a specific simulator

```bash
export UDID="<simulator-udid>"   # from simctl list devices booted
export BUNDLE_ID="com.example.app"
```

Every `idb` and `simctl` call below should pass `--udid $UDID` where supported.

## Device discovery & boot

```bash
# List booted simulators (preferred - ready to use)
xcrun simctl list devices booted

# List all available simulators
xcrun simctl list devices available

# Boot a simulator by UDID
xcrun simctl boot "$UDID"
```

Decision logic:
- 0 booted → pick a reasonable device (e.g. iPhone 16), boot it; `open -a Simulator` unless `--headless`.
- 1 booted → use it.
- >1 booted → **ask the user** which UDID.

## Build, install & launch

Substitute `ios.*` from `tapwright.config.yml`. Generic recipe:

```bash
# Optional: set any resource/flavor env your scheme's pre-action expects
# launchctl setenv MY_RESOURCE_FLAVOR <flavor>

# Build (config: ios.build) - example
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme AppDebug \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath ./build/DerivedData \
  build

# Install - locate the built .app under DerivedData (name may contain spaces)
APP_PATH=$(find ./build/DerivedData -name '*.app' -type d | head -1)
xcrun simctl install "$UDID" "$APP_PATH"

# Launch (config: ios.bundle_id)
xcrun simctl launch "$UDID" com.example.app
```

Prefer an existing built `.app` under DerivedData when present, to skip a full rebuild.

## idb companion (required for UI interaction)

Before `idb ui` commands, start the companion for the target simulator (background):

```bash
idb companion --udid "$UDID" &
sleep 2
```

If `idb ui` fails with connection errors, restart the companion.

## Inspecting the screen (primary)

```bash
idb ui describe-all --udid "$UDID" --json > /tmp/ios-ui.json
# grep AXLabel / frame → idb ui tap
# Checkpoint (shrunk) - use helper, not raw simctl:
source pack/scripts/ios-helpers.sh
screenshot "$RESOURCES/checkpoint.png"
```

Parse JSON for `AXLabel`, `AXValue`, or `frame`. Tap center: `x + width/2`, `y + height/2`.

**Compose / cross-platform on iOS:** search JSON for the label substring; if labels differ from Android, match your string-resource keys (from the code dig) instead.

## VLM (fallback only)

Read a checkpoint PNG when the accessibility tree does not expose what you need or the screen is ambiguous. Checkpoints are <=540px long-edge - still readable for text/layout.

## Checkpoint images

```bash
export UDID="<simulator-udid>"
source pack/scripts/ios-helpers.sh
mkdir -p "$RESOURCES"
screenshot "$RESOURCES/checkpoint.png"
# writes checkpoint.png.meta: orig_w/h out_w/h scale_x/y
```

| Rule | Detail |
|---|---|
| Max long-edge | **540px** (`shrink-screenshot.sh`) |
| Sidecar | `$png.meta` - `scale_* = orig/out` (full-res pixels / shrunk pixels) |
| Taps | **From `idb` AX frames (points)** when available |
| Image → tap (rare) | Map shrunk → full pixels with scale, then divide by display scale (usually 3) to get points - prefer AX instead |

Do **not** use raw `xcrun simctl io ... screenshot` for checkpoints in `/test` / `/exec`.

## Interactions

```bash
export RESOURCES="./.tapwright-run/resources"    # /test sets this to the run folder

# Tap at coordinates (from accessibility frame center - not from shrunk PNG)
idb ui tap --udid "$UDID" 200 400

# Swipe - scroll up to reveal content below (coordinates depend on device size)
idb ui swipe --udid "$UDID" --start 200,600 --end 200,200 --duration 0.3

# Type text into focused field
idb ui text --udid "$UDID" "hello"

# Screenshot checkpoint (shrunk)
source pack/scripts/ios-helpers.sh
mkdir -p "$RESOURCES"
screenshot "$RESOURCES/checkpoint.png"
```

## App lifecycle

```bash
# Launch
xcrun simctl launch "$UDID" "$BUNDLE_ID"

# Terminate (teardown - equivalent to Android force-stop)
xcrun simctl terminate "$UDID" "$BUNDLE_ID"

# Uninstall (reset app state)
xcrun simctl uninstall "$UDID" "$BUNDLE_ID"
```

## Batching & speed

```bash
idb companion --udid "$UDID" &
sleep 2
xcrun simctl launch "$UDID" "$BUNDLE_ID"
sleep 5
idb ui tap --udid "$UDID" 200 800    # example: tab bar tap (points)
sleep 2
source pack/scripts/ios-helpers.sh
screenshot "$RESOURCES/e1-open.png"
```

Guidelines:
- Short `sleep` (0.3-1s) between taps; 3-8s after launch or network-heavy screens.
- Name checkpoint files under the run's `resources/` folder; reference as `resources/<file>` in DSL.
- Always capture checkpoints via `screenshot` helper (<=540 long-edge + `.meta`).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `idb: command not found` | `pip3 install fb-idb` |
| `idb ui` connection refused | Run `idb companion --udid $UDID` in background |
| `xcodebuild` destination not found | `xcrun simctl list devices available` - pick installed runtime name |
| Build fails on flavor/resource env | Set the env your scheme's pre-action expects (`launchctl setenv ...`) |
| Element not in tree | Swipe to reveal; retry `describe-all`; check `AXLabel` not just text |
| No booted simulator | `xcrun simctl boot <UDID>`; `open -a Simulator` unless `--headless` |
| User didn't see the test run | Re-run without `--headless` (default opens Simulator.app) |
