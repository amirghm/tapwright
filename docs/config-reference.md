# Config reference - `tapwright.config.yml`

Place `tapwright.config.yml` at the root of your working folder. It tells the pack
where source lives, when available, and how to build/launch your app. **Everything is optional** - with no config,
tapwright falls back to probing the string/nav globs below and expects you to pass
package/bundle ids inline in your `/exec` sentence. Filling it in makes runs faster and
deterministic.

Source code is optional. With no app repo, tapwright uses the App Map and live UI
instead of `string_globs` and `nav_globs`.

Start from [`config/tapwright.config.example.yml`](../config/tapwright.config.example.yml).

## Fields

### `app_source_dir`
Root directory the agent greps when the App Map is missing a route or needs a
stale path refreshed. Default `./`.

### `string_globs`
Globs to the files that hold user-visible labels. Phase 0 greps these for exact CTA and
screen-title text (plus locale variants) so the step plan uses real strings instead of
guesses. Keep the presets matching your stack; delete the rest. See
[supported-stacks.md](supported-stacks.md) for per-stack presets.

### `nav_globs`
Globs to navigation/route definitions. Consulted when the next screen after an action is
unclear or after two failed taps.

### `locales`
Language codes whose label variants the agent should grep for in the live UI dump. Include
every language your app might show (e.g. `[en, de]`). Apps commonly mix a localized account
UI with English chrome.

### `android`
| Key | Meaning |
|---|---|
| `package_id` | `applicationId` of the build under test; used for launch/force-stop/`pm clear` and to bias `tap_text` (`export PKG=...`). |
| `launch` | `adb shell am start -n` target (`package/.Activity`). |
| `install` | Command (run from `app_source_dir`) that installs the build - e.g. a Gradle task. |
| `apk` | Optional path to a prebuilt debug APK for `adb install -r -t` (faster than Gradle). |

### `ios` (macOS only)
| Key | Meaning |
|---|---|
| `bundle_id` | Bundle identifier to launch/terminate. |
| `scheme` / `config` | Xcode scheme + build configuration. |
| `build` | `xcodebuild ...` command; tapwright locates the resulting `.app` under DerivedData and installs it. |
| `resource_flavor_env` | Optional `launchctl setenv` value if your scheme's pre-action needs it. |

### `accounts` (optional)
Named accounts for login flows. **Never commit passwords** - use `password_env` to name an
environment variable the agent reads at runtime. Briefs and summaries print the email only.

### `known_flows` (optional)
User-authored fast paths: an ordered list of steps for an app-specific journey. Each step
has an expected `screen`, an `action` (`tap`/`type`/`scroll`/`key`/`confirm`), `needles`
(label text to find in the dump, across your `locales`), and a `success` signal expected in
the next dump. tapwright still verifies each step against the live dump - `known_flows` just
skips re-deriving the plan from source every run. This is how you teach tapwright your app's
equivalents of "cancel account" or "reset onboarding".

## Secrets

- Passwords: reference `password_env`, never inline literals.
- tapwright never writes credentials to reports, DSL, or shell history it controls.
- Add `tapwright.config.yml` to `.gitignore` if it contains account emails you'd rather not commit.

## Zero-config behavior

If `tapwright.config.yml` is absent, the agent:
1. Reads the per-app App Map when an app ID is known.
2. Detects the foreground package/bundle when possible, or asks one short
   question when several apps are plausible.
3. Derives and verifies the plan from the App Map and live UI.
4. Uses built-in `string_globs` / `nav_globs` only when a live target remains
   unresolved and source files exist.
