---
name: Device Interaction (Android adb)
description: |
  Reusable Android device/emulator control skill built on `adb`. Use this skill whenever:
  - You need to run an app on an Android emulator or device and interact with it (tap, type, swipe, screenshot).
  - The `/test` workflow (default, no `--ios` flag) needs to drive a real screen.
  - The `/exec` workflow needs to drive a real screen from a natural-language task.
  - The user asks to "take a screenshot", "tap", "long press", "swipe", "type text", "press back/home", or otherwise automate a phone/emulator.
  - You need to discover, boot, or choose between connected Android devices/emulators.
  For iOS Simulator use the device-interaction-ios skill instead.
  App-specific values (applicationId, launch activity, install command) come from `tapwright.config.yml`.
---

# Device Interaction (Android via `adb`)

A thin, copy-pasteable layer over `adb` for driving an Android emulator (or, with explicit consent, a physical device). The agent runs these commands with the Shell tool.

**iOS Simulator:** see the `device-interaction-ios` skill (`simctl` + `idb`).

**Config:** read `tapwright.config.yml` for `android.package_id`, `android.launch`, and `android.install`. Examples below use `com.example.app` / `.MainActivity` - substitute the config values.

## Golden rules

1. **Never touch a physical device without explicit user confirmation.** Emulator serials start with `emulator-` (e.g. `emulator-5554`). Any other serial is a physical phone - stop and ask before interacting with it.
2. **Prefer emulators.** If no emulator is running, boot one (see below) rather than falling back to a physical device.
3. **Disambiguate multiple devices.** If more than one device is online, ask the user which one, then pass `-s <serial>` to every `adb` call.
4. **Batch for speed.** Chain several actions with `sleep` in a single Shell call. Screenshot only at checkpoints - not after every tap. See [Batching & speed](#batching--speed).
5. **Resolve selectors, don't guess coordinates.** Dump the view hierarchy first; grep text/bounds before tapping (see [Inspecting the screen](#inspecting-the-screen)).
6. **Assert from dump when possible.** Grep for label/subtitle/gate text. Use VLM on a checkpoint PNG only when what you need is not in the tree.
7. **Helpers.** `source pack/scripts/adb-helpers.sh` - `dump_ui`, `tap_text`, `has_plus`, `screenshot` (auto-shrinks to max long-edge 540). Set `PKG=<applicationId>` to bias `tap_text` toward your app's nodes.
8. **No Python orchestration scripts.**
9. **Taps from dump, not PNG.** Checkpoint screenshots are shrunk for VLM/reports; never derive tap coords from the shrunk image when dump bounds exist.

## Setup: target a specific device

Every command below assumes a single device. When multiple are online, export the serial once and reuse it:

```bash
export ADB="adb -s emulator-5554"   # replace with the chosen serial
$ADB shell input tap 540 1200
```

## Device discovery & boot

```bash
# List online devices with details (model, product, transport id)
adb devices -l

# List available emulator images (AVDs)
emulator -list-avds

# Boot an emulator headless-ish in the background (does not block the shell)
emulator -avd <avd_name> -netdelay none -netspeed full &

# Wait until the device finishes booting before interacting
adb wait-for-device shell 'while [[ "$(getprop sys.boot_completed)" != "1" ]]; do sleep 1; done'
```

Decision logic:
- 0 devices online -> `emulator -list-avds`, boot one, wait for boot.
- 1 emulator online -> use it.
- 1 physical device only -> **ask the user** before proceeding.
- >1 online -> **ask the user** which serial, then set `$ADB` with `-s`.

## Inspecting the screen (primary)

Resolve elements before interacting - this is the default path, not a fallback.

```bash
# Screen resolution (needed to compute relative coordinates)
$ADB shell wm size

# Dump the current view hierarchy and pull it locally to read bounds / resource-id / text
$ADB exec-out uiautomator dump /dev/tty
# or write to a file and pull:
$ADB shell uiautomator dump /sdcard/window_dump.xml && $ADB pull /sdcard/window_dump.xml ./window_dump.xml

# Which activity is currently focused (useful for assertions)
$ADB shell dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity'
```

From a node's `bounds="[x1,y1][x2,y2]"`, tap the center: `x = (x1+x2)/2`, `y = (y1+y2)/2`.

Or use helpers after `source pack/scripts/adb-helpers.sh`:
```bash
export SERIAL=emulator-5554
export PKG=com.example.app          # from tapwright.config.yml (optional but recommended)
dump_ui /tmp/window_dump.xml
tap_text /tmp/window_dump.xml "Delivery details"
```

## VLM (fallback only)

Screenshot at checkpoints via helper (auto-shrunk); read the PNG only when the dump cannot confirm what you need (values rendered on chips/canvas, ambiguous screen identity). Content remains readable at <=540px long-edge.

## Checkpoint images

Always use the helper (captures full-res, then shrinks in place):

```bash
export SERIAL=emulator-5554
source pack/scripts/adb-helpers.sh
mkdir -p "$RESOURCES"
screenshot "$RESOURCES/checkpoint-post-login.png"
# writes checkpoint-post-login.png.meta: orig_w/h out_w/h scale_x/y
```

| Rule | Detail |
|---|---|
| Max long-edge | **540px** (`shrink-screenshot.sh` / `sips -Z 540`) |
| Sidecar | `$png.meta` - `scale_* = orig/out` if you must map image → device pixels |
| Taps | **From uiautomator dump bounds only** when available |
| Image → tap (rare) | `tap_x = image_x * scale_x`, `tap_y = image_y * scale_y` |

Do **not** use raw `$ADB exec-out screencap` for checkpoints - it skips the shrink and burns VLM tokens.

## Interactions

```bash
# Screenshot checkpoint (shrunk) - prefer helper
# Run once per non-E2E request. Preserve /test's spec run folder when provided.
if [[ -z "${RESOURCES:-}" ]]; then
  if [[ -z "${TAPWRIGHT_RUN_DIR:-}" ]]; then
    export TAPWRIGHT_RUN_DIR="$(pack/scripts/new-run-dir.sh run)"
  fi
  export RESOURCES="$TAPWRIGHT_RUN_DIR/resources"
fi
source pack/scripts/adb-helpers.sh
export SERIAL=emulator-5554
screenshot "$RESOURCES/checkpoint-post-login.png"

# Tap at coordinates (from dump bounds - not from shrunk PNG)
$ADB shell input tap 540 1200

# Long press (emulated as a same-point swipe with a long duration, ms)
$ADB shell input swipe 540 1200 540 1200 700

# Swipe / scroll (x1 y1 x2 y2 durationMs). Swipe UP to scroll down:
$ADB shell input swipe 540 1600 540 600 300

# Type text into the focused field.
type_text 'hello world'

# Long prompts: pass the text through stdin. Newlines become safe spaces and do
# not submit the field; submit explicitly after type_text finishes.
type_text <<'TEXT'
Create a calm daily planner with a Today board, priorities, and a focus timer.
Keep the experience simple and verify the main flow.
TEXT

# Key events (physical / navigation buttons)
$ADB shell input keyevent 4    # BACK
$ADB shell input keyevent 3    # HOME
$ADB shell input keyevent 66   # ENTER
$ADB shell input keyevent 67   # DEL (backspace)
$ADB shell input keyevent 187  # APP_SWITCH (recents)
$ADB shell input keyevent 26   # POWER
$ADB shell input keyevent 24   # VOLUME_UP
$ADB shell input keyevent 25   # VOLUME_DOWN
```

Text-entry tips:
- Use `type_text`; never encode spaces as `%s` or send long prose through raw
  `adb shell input text`.
- `type_text` turns whitespace, including newlines, into spaces. Submit the field
  explicitly only after the complete value has been entered.
- `type_text` supports ASCII and fails before typing unsupported Unicode. Use a
  Unicode-capable device keyboard when the requested text contains non-ASCII.
- To clear a field: focus it, then `$ADB shell input keyevent KEYCODE_MOVE_END` and hold `67` (DEL) enough times, or select-all + delete via the keyboard.

## App lifecycle helpers

Substitute `android.package_id` / `android.launch` from `tapwright.config.yml`:

```bash
# Launch the app's main/splash activity (config: android.launch)
$ADB shell am start -n com.example.app/.MainActivity

# Force-stop before a clean run
$ADB shell am force-stop com.example.app

# Clear app data to reset onboarding/login state
$ADB shell pm clear com.example.app
```

## Batching & speed

Do NOT do `action -> screenshot -> action -> screenshot`. Instead group actions and insert `sleep` for animations/network, screenshotting only at checkpoints:

```bash
# Example: open app, wait for splash, tap login, fill email, submit - one checkpoint at the end
source pack/scripts/adb-helpers.sh
export SERIAL=emulator-5554
$ADB shell am start -n com.example.app/.MainActivity
sleep 4
$ADB shell input tap 540 1500      # "Log in"
sleep 1
$ADB shell input tap 540 700       # email field
type_text 'qa@example.com'
$ADB shell input tap 540 900       # password field
type_text "$PASSWORD"
$ADB shell input keyevent 66
sleep 5
screenshot "$RESOURCES/checkpoint-post-login.png"
```

Guidelines:
- Use short `sleep` (0.3-1s) between UI taps, longer (3-6s) after launches, logins, or network calls.
- Capture a screenshot after each meaningful state change (screen transition, submitted form, assertion point), not after every tap - always via `screenshot` helper (<=540 long-edge).
- Name checkpoint files under the run's `resources/` folder (see `/test` workflow).
