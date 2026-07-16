# Getting started

This gets tapwright installed in a mobile repo and runs a first `@mobile inspect`.

## 1. Install prerequisites

- **Android:** Android SDK platform-tools (`adb` on your PATH) and an emulator (AVD) or a
  connected device with USB debugging.
- **iOS (macOS only):** Xcode + a Simulator runtime, plus `idb`:
  ```bash
  brew tap facebook/fb && brew install idb-companion
  pip3 install fb-idb   # or: pipx install fb-idb
  ```

Sanity checks:
```bash
adb devices -l
xcrun simctl list devices booted   # macOS
```

## 2. Install the pack into your app repo

Recommended: send this page to your coding agent and ask it to install tapwright in the current repo:

```text
https://raw.githubusercontent.com/amirghm/tapwright/main/docs/install-agent.md
```

From a local checkout, use [install-agent.md](install-agent.md). That page tells the agent what
to clone, what command to run, and what to try first.

Manual local install:

```bash
git clone https://github.com/amirghm/tapwright.git
cd /path/to/your-app
/path/to/tapwright/install.sh          # detects .cursor / .claude / .agents
```

The installer copies the pack into `<agent-dir>/{workflows,skills,scripts,templates}` and
seeds a starter `tapwright.config.yml`. If your agent reads slash commands from a dedicated
folder (e.g. `.claude/commands`), the installer adds best-effort adapters and tells you
what it installed.

## 3. Describe your app

Edit `tapwright.config.yml`. Start with these fields:

```yaml
android:
  package_id: com.yourco.app.debug
  launch: com.yourco.app.debug/.MainActivity
  install: "./gradlew installDebug"
ios:
  bundle_id: com.yourco.app
  scheme: AppDebug
  build: "xcodebuild -scheme AppDebug -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath ./build/DerivedData build"
string_globs: [ "**/res/values*/strings.xml" ]   # match your stack (see supported-stacks.md)
locales: [en]
```

See [config-reference.md](config-reference.md) for every field and
[supported-stacks.md](supported-stacks.md) for per-framework glob presets.

## 4. Run `@mobile inspect`

In your agent:

```
@mobile inspect
```

The agent selects an emulator or simulator, reads `tapwright.config.yml` if it exists, dumps the
current UI tree, and summarizes what it found. It may save a small screenshot if that helps.

## 5. Run `@mobile automate` (ad-hoc)

In your agent:

```
@mobile automate on android: log in as qa@example.com and open the account screen
```

The agent looks through your strings and navigation files for the labels it needs, builds a short
plan, launches the app, then dumps the UI tree and taps matching elements. You get a chat summary.

Compatibility alias: `/exec on android: ...`

## 6. Run `@mobile test` (spec)

Create `specs/<SPEC>/test-plan.md` from [../pack/templates/test-plan.md](../pack/templates/test-plan.md),
then:

```
@mobile test <SPEC>            # Android
@mobile test <SPEC> --ios      # iOS (visible simulator)
@mobile test <SPEC> --ios --headless
```

Output lands in `specs/<SPEC>/runs/<platform>/<run_id>/`: a `test-report.md`, one
`e-<n>-*.dsl.yaml` per scenario, and shrunk screenshots under `resources/`.

Compatibility alias: `/test <SPEC>`

## Tips

- **Speed:** say "fast"/"headless" in `@mobile automate` to batch taps and shorten pauses.
- **Login without leaking secrets:** put the password in an env var and reference it via
  `accounts.default.password_env` in the config.
- **Teach a recurring journey:** add it under `known_flows` so the agent skips re-deriving it.
- **When it gets stuck:** it re-greps your source after two failed taps; keep `string_globs`
  pointed at the right files to make that fast.
