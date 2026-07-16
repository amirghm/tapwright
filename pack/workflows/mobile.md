---
description: Mobile workflow for inspecting, automating, manually testing, debugging, recording, replaying, comparing, and running E2E flows on Android/iOS.
---

# `@mobile`

**Goal:** Give the user one visible mobile command. This workflow handles mobile
inspection, automation, manual UI checks, debugging, recording, replay, compare,
and E2E runs.

**Read first:** the `mobile-engine` skill. It routes to:

| Need | Skill / workflow |
|---|---|
| Android device control | `device-interaction` |
| iOS Simulator control | `device-interaction-ios` |
| Ad-hoc automation | `exec-engine` / `/exec` behavior |
| E2E execution | `test-engine` / `/test` behavior |

## Usage

```text
@mobile what screen is my app showing?
@mobile log in and open the account screen
@mobile manual test checkout on android
@mobile test CHECKOUT --ios --headless
@mobile debug app launch
@mobile record onboarding
@mobile replay specs/CHECKOUT/runs/android/<run_id>/e-1-checkout.dsl.yaml
@mobile compare current screen with <reference>
```

If the coding tool does not support `@mobile`, use `/mobile` instead. Both forms
run this workflow.

## Mode Selection

Infer the mode from the request:

| Mode | Route |
|---|---|
| `inspect` | Dump current UI, optional screenshot, summarize state |
| `automate` | Execute natural-language goal with `/exec` semantics |
| `manual` | Guided one-step UI testing |
| `test` | Execute `test-plan.md` with `/test` semantics |
| `debug` | Collect dump, screenshot, app/device state, optional logs |
| `record` | Execute and save provisional DSL under `.tapwright-run/` |
| `replay` | Execute an existing DSL/test flow |
| `compare` | Capture checkpoint and compare to provided reference/design |

Default platform: Android. Use iOS when the user says iOS/simulator or passes
`--ios`.

## Safety Defaults

- Prefer emulators/simulators.
- Physical devices require explicit user confirmation before interaction.
- Resolve from UI dumps/accessibility trees before tapping.
- Screenshots are evidence/fallback, not the primary selector system.
- Stop on gates and destructive confirmations unless the request explicitly
  includes that action.

## Artifacts

- `test` mode writes `specs/<SPEC>/runs/<platform>/<run_id>/`.
- Other modes may write `.tapwright-run/` scratch evidence when useful.
- Simple automation can be chat-only.

## Flow

```mermaid
flowchart TD
    A["@mobile request"] --> B[Read mobile-engine skill]
    B --> C{Mode?}
    C -->|inspect/debug/manual| D[Device skill]
    C -->|automate| E[exec-engine]
    C -->|test| F[test-engine]
    C -->|record/replay| G[DSL + device skill]
    C -->|compare| H[Screenshot + reference review]
    D --> I[Summary / optional scratch artifacts]
    E --> I
    F --> J[Report + DSL]
    G --> I
    H --> I
```
