---
name: mobile-engine
description: |
  Routing engine for the tapwright @mobile workflow. Use this skill whenever the
  user runs @mobile or /mobile, or asks an agent to inspect, automate, manually
  test, debug, record, replay, compare, or run E2E flows on an Android
  emulator/device or iOS Simulator. This skill routes to the existing
  exec-engine, test-engine, device-interaction, and device-interaction-ios
  skills; it is not a separate runtime, daemon, SDK, or MCP server.
---

# mobile-engine

`@mobile` is the main tapwright entrypoint for mobile work. Use it to inspect a
real app screen, act on it, verify the result, and save evidence when useful.

It is a **router skill**. Do not duplicate platform recipes here:

- Android control: `device-interaction`
- iOS control: `device-interaction-ios`
- Natural-language automation: `exec-engine`
- E2E spec execution and reports: `test-engine`

## User mental model

`@mobile` is the primary experience. If the coding tool does not recognize it,
the user can type `/mobile` instead. `mobile-engine` is only the helper skill
behind both forms, so command pickers do not show two different `mobile` entries.

```text
@mobile inspect
@mobile log in as qa@example.com and open Settings
@mobile manual test the checkout screen
@mobile test CHECKOUT --ios --headless
@mobile debug why the app is stuck on launch
@mobile record onboarding
@mobile replay specs/CHECKOUT/runs/android/<run_id>/e-1-checkout.dsl.yaml
@mobile compare this screen with <design/reference>
```

## Modes

Infer the mode from the user's words. If the request is ambiguous, choose the
least surprising mode and say which one you chose in the brief.

| Mode | Triggers | Output |
|---|---|---|
| `inspect` | inspect, current screen, what do you see, screenshot, dump | Chat summary; optional timestamped evidence |
| `automate` | automate, do, complete, open, log in, navigate, toggle | Same behavior as `/exec`; chat summary by default |
| `manual` | manual test, guide me, step by step, watch it | One action/checkpoint at a time; chat summary |
| `test` | test, e2e, spec, `test-plan.md`, `/test` | Same behavior as `/test`; report + DSL |
| `debug` | debug, logs, stuck, failed, why | Logs + dump + screenshot summary; optional scratch evidence |
| `record` | record, turn this into DSL, capture flow | Provisional DSL in the request's run folder |
| `replay` | replay, run this DSL | Execute DSL/test flow; summary + optional evidence |
| `compare` | compare, design, screenshot diff, Figma, reference | Side-by-side qualitative notes; optional evidence |

## Platform defaults

- Default platform is Android unless the user says iOS/simulator.
- Android uses emulators by default.
- iOS uses Simulators by default.
- Physical Android/iOS devices require explicit user confirmation before any
  interaction. Listing devices is fine; tapping, typing, launching, installing,
  clearing state, or reading private app data is not.

## App Memory

Every task must use the app-specific App Map before planning or touching the UI.

1. Resolve the platform and app ID from `tapwright.config.yml`, the request, or
   the selected app (`android.package_id` / `ios.bundle_id`). Never create memory
   for placeholder values such as `com.example.app`; detect or ask for the real
   installed app ID first.
2. Initialize or locate the App Map:

```bash
export TAPWRIGHT_MEMORY="$(pack/scripts/memory-path.sh <platform> <app-id>)"
```

```powershell
$env:TAPWRIGHT_MEMORY = & "pack/scripts/memory-path.ps1" -Platform <platform> -AppId <app-id>
```

3. Read the map before any source digging. If it contains a complete route for
   the request and its start-screen markers match the live UI, use that route
   directly. Do not inspect source code for steps the map already covers.
   For a large map, search task keywords and load only the connected nodes and
   edges needed for the request.
4. When source code is available, inspect it only for missing edges,
   stale/low-confidence entries, a changed app version, or a live UI conflict.
   Keep that search limited to the gap.
5. When no source code exists, continue from the live accessibility tree/UI dump
   and update the map from verified interactions. Missing source is not a blocker.
6. Validate remembered markers and selectors against the current dump before
   every action. Memory is a hint, not proof.
7. Read the installed app version when available. After the task, merge verified
   screens, stable targets, transitions, gates, app versions, timestamps, hits,
   misses, and confidence into the same map.

The App Map lives at
`.tapwright-memory/<platform>/<package-or-bundle-id>/app-map.yaml`. Never store
coordinates, screenshots, raw dumps, secrets, credentials, personal data, or
dynamic account content in memory. Keep those in the timestamped run folder when
they are needed as evidence.

### No-repo use

tapwright does not require app source or a Git repo. Use the current working
folder as the tapwright workspace. Resolve the app ID from the foreground app or
installed-app list when possible. On Android, inspect the focused activity with
`adb shell dumpsys window`; on iOS, use the configured/selected bundle from the
Simulator app list. If several apps are plausible, ask one short question.

With no source, plan from the App Map and live UI only. Create and improve the
same per-app map after each request.

## Mode routing

### Non-E2E run folder

When a non-E2E request needs files, create one folder at the start and reuse it
for the whole request:

```text
.tapwright-run/<YYYY-MM-DD>/<HH-mm-ssZ>-<mode>/
```

Initialize it once per request:

```bash
export TAPWRIGHT_RUN_DIR="$(pack/scripts/new-run-dir.sh <mode>)"
```

```powershell
$env:TAPWRIGHT_RUN_DIR = & "pack/scripts/new-run-dir.ps1" -Mode <mode>
```

If a folder already exists for the same second, the helper adds `-2`, `-3`, and
so on. Do not create a new folder for every action or screenshot in the same
request.

### inspect

Read `tapwright.config.yml` if present, then use the platform device skill.

Minimum useful inspection:

1. List/select target emulator or simulator.
2. Report app identity from config when available (`android.package_id` /
   `ios.bundle_id`).
3. Dump the UI tree (`uiautomator` XML or `idb ui describe-all` JSON).
4. Capture a screenshot only when useful; if saved, use
   `$TAPWRIGHT_RUN_DIR/resources/`.
5. Summarize visible labels, focused activity/bundle, and likely current screen.

### automate

Route to `exec-engine` and the relevant platform skill. Preserve `/exec`
semantics:

1. Build a compact step plan from a matching App Map route when available.
2. Dig into code only for gaps or stale/conflicting memory when source exists;
   otherwise fill gaps from the live UI.
3. Execute with dump-first taps.
4. Screenshot/VLM only when the dump is insufficient.
5. Chat summary only unless scratch evidence is useful.

### manual

Use the platform device skill, but optimize for watchability:

1. Inspect the current screen.
2. Propose the next concrete UI action/check.
3. Execute one action or a very small group.
4. Re-inspect and report the result.
5. Continue until the requested manual check is done.

Do not produce E2E reports unless the user asks to turn the session into a test
or record.

### test

Route to `test-engine` and `pack/workflows/test.md`. Preserve `/test`
semantics:

- Read and verify the spec before touching the device.
- Create `specs/<SPEC>/runs/<platform>/<run_id>/`.
- Write `test-report.md`, DSL, and resources.

### debug

Gather enough evidence for the user or agent to fix code:

- current device/simulator
- current app/activity/bundle
- UI dump
- screenshot
- platform logs when requested or when failure is app-launch/runtime related
- recent gate/blocker text from the dump

Save evidence under `$TAPWRIGHT_RUN_DIR/` when it helps.

### record

Record the actions actually taken, not guesses. Use the same dump-first loop as
automation, then write provisional DSL under `$TAPWRIGHT_RUN_DIR/`.

The DSL may be incomplete, but it must include:

- platform and app id
- ordered actions
- selectors used
- waits
- screenshots/dumps referenced when captured
- TODO comments for unstable selectors or manual decisions

### replay

Read the DSL/test flow, map selectors to the platform skill, then execute with
normal dump-first verification. If a selector is stale, stop and report the
first failing step rather than guessing coordinates.

### compare

Capture the mobile checkpoint with the platform screenshot helper. If a design
or reference image is available, compare qualitatively:

- major layout/component differences
- missing/extra visible copy
- spacing/alignment concerns visible at checkpoint scale
- pass/review/fail recommendation

This is assisted review, not pixel-perfect visual regression.

## Artifacts

- E2E/test mode always writes report, DSL, and resources under
  `specs/<SPEC>/runs/...`.
- Non-E2E modes may write scratch evidence under
  `.tapwright-run/<date>/<time>-<mode>/` when useful.
- Simple automation can remain chat-only.
- Never write passwords or secrets to artifacts.
- App Memory is persistent project knowledge, separate from run artifacts.

## Safety

- Do not touch physical devices without explicit user confirmation.
- Never random-tap when the UI dump cannot identify a target.
- Stop on gates such as disabled controls, unavailable states, wrong account
  state, or destructive confirmations that were not requested.
- Keep screenshots shrunk via helpers before using VLM.
