# Getting started

This gets tapwright installed in a mobile repo and runs a first `@mobile` request.

## 1. Send the install link to your agent

Ask your coding agent to install tapwright in the current repo:

```text
https://raw.githubusercontent.com/amirghm/tapwright/main/docs/install-agent.md
```

The agent should clone tapwright, run the right installer for your OS, check mobile tooling,
and report anything missing. Windows is supported for Android. iOS is macOS-only.

## 2. Describe your app

The agent should create `tapwright.config.yml` if it does not exist. Start with these fields:

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

## 3. Ask what the app is showing

In your agent:

```
@mobile what screen is my app showing?
```

The agent selects an emulator or simulator, reads `tapwright.config.yml` if it exists, dumps the
current UI tree, and summarizes what it found. It may save a small screenshot if that helps.

## 4. Ask it to do a job

In your agent:

```
@mobile log in with qa@example.com and open the account screen
```

The agent looks through your strings and navigation files for the labels it needs, builds a short
plan, launches the app, then dumps the UI tree and taps matching elements. You get a chat summary.

Compatibility alias: `/exec on android: ...`

## 5. Run `@mobile test` (spec)

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

- **Speed:** say "fast"/"headless" in `@mobile` requests to batch taps and shorten pauses.
- **Login without leaking secrets:** put the password in an env var and reference it via
  `accounts.default.password_env` in the config.
- **Teach a recurring journey:** add it under `known_flows` so the agent skips re-deriving it.
- **When it gets stuck:** it re-greps your source after two failed taps; keep `string_globs`
  pointed at the right files to make that fast.
