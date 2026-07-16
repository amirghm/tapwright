---
name: test-engine
description: |
  Mobile test-plan execution engine for tapwright. Use this skill whenever:
  - The user runs `/test SPEC`, `/test SPEC --ios`, or `/test SPEC --ios --headless`, or asks to execute a mobile test plan on an emulator/simulator.
  - You need to verify E2E scenarios against the actual app codebase before driving adb or idb.
  - You are writing or improving a spec's `test-plan.md` with agent-executable steps.
  - The user mentions test execution, e2e DSL, or running staging/QA verification on a device.
  ALWAYS read this skill before executing `/test`. Do not skip codebase verification.
---

# Test Engine

Orchestrates `/test` - but **never jump straight to a device**. First verify scenarios in the app codebase, post a short execution brief in chat, then execute immediately. `/test` is a run command; do not wait for a second confirmation.

**Platform skills:**
- Android (default): `device-interaction`
- iOS (`--ios`): `device-interaction-ios`

**Config:** `tapwright.config.yml` supplies source globs, package/bundle ids, build/launch commands, accounts, and `known_flows`.

**Output conventions:** read `pack/templates/e2e.md` before writing anything under `specs/<SPEC>/runs/`.

## Phase 0 - Codebase verification (mandatory before execution)

For every E2E scenario in the test plan, trace the real implementation in the app source:

1. **Find the UI surface** - grep `string_globs` and screen definitions for the labels the scenario names.
2. **Find entry navigation** - read files matched by `nav_globs`.
3. **Find gating conditions** - states/flags that enable or hide the control under test (e.g. an item is only editable in a certain status).
4. **Find exact string keys** - in the string-resource files (check each locale in `tapwright.config.yml`).
5. **Note layout differences** - list vs chips, bottom sheet vs full screen, differing CTAs.

Document findings in a short **Execution brief** (format below). If the test plan contradicts the code, **update the test plan** or flag the gap to the user.

### Gates (generic)

A "gate" is any code condition that must hold for a step to be reachable. When a gate fails, the UI shows a different state - the agent must **stop and report blocked**, never guess coordinates. Record the gates you find per scenario so the run can recognize them in the dump. Encode recurring preconditions as `known_flows` setup steps in config.

## Phase 1 - Execution brief (mandatory before device)

Produce this brief in chat, then **start device execution immediately** - no approval gate:

```markdown
## /test <SPEC> - Execution brief

### Platform
- android (default) | ios (`--ios`)
- iOS visibility: `visible` (default) | `headless` (`--headless`)

### Codebase verification summary
- [E-1] Entry: ... | Gate: ... | Strings (per locale): ...
- [E-2] ...

### Accounts & setup
- E-1-E-N: [account] state, any setup steps

### Device
- Android: emulator-XXXX | iOS: simulator UDID + idb companion

### Scenario run order
1. E-1 → ...

### Risks / blockers
- ...
```

The brief is informational only. Proceed to device steps as soon as it's posted.

## Phase 2 - Execute

Follow `pack/workflows/test.md` and the platform device skill. **Few Shell calls; dump-first.**

### Runtime loop (fast)

| # | Action | Tool |
|---|---|---|
| 1 | Dump UI | `uiautomator` / `idb ui describe-all` |
| 2 | Grep + tap | text/bounds → `input tap` / `idb ui tap` |
| 3 | Batch | 2-5 steps + `sleep` in **one** Shell call (headless) |
| 4 | Assert | grep the dump - not VLM unless the dump is insufficient |
| 5 | Checkpoint | `screenshot` helper (<=540 long-edge + `.meta`); optional VLM on that PNG; taps still from dump/AX |
| 6 | YAML | after the scenario completes |

**Anti-patterns:** VLM every tap, one Shell per tap in headless, re-dump without tapping, long mid-run narration, raw full-res `screencap`/`simctl` without shrink.

**Never** write DSL before executing. YAML = record of a finished run.

### Deadlock only (2 failed taps)

Grep the source (strings → navigation → gates) → resume with code-backed labels. Promote the fix to the test plan. No VLM unless the dump is still ambiguous.

Platform setup:
- **Android:** `device-interaction` + `adb-helpers.sh`
- **iOS:** `device-interaction-ios` + `ios-helpers.sh` → build + `simctl` + `idb`

## Phase 3 - Report & DSL

At run start, set `run_id` to UTC `YYYY-MM-DDTHH-mm-ssZ` and output everything under:

`specs/<SPEC>/runs/android/<run_id>/` or `specs/<SPEC>/runs/ios/<run_id>/`

- **test-report.md** - from `pack/templates/test-report.md`
- **DSL** - one file per scenario: `e-<n>-<slug>.dsl.yaml`
- **resources/** - screenshots (<=540 long-edge via helpers + `.meta`) and UI dumps (reference as `resources/<file>` in DSL steps)
- Patterns catalog: `pack/templates/e2e-patterns.yaml`

Re-running `/test` always creates a **new** `<run_id>` folder; previous runs are preserved.

### Dynamic data in DSL (do not hardcode volatile content)

Steps must survive different accounts, dates, and locales:

| Brittle (avoid in promoted DSL) | Stable alternative |
|---|---|
| A specific date label | `discover` → bind a `vars.*` at runtime |
| A specific amount/price | `assert` with `intent` + a `pattern` regex |
| Assuming which option shows a state | `discover` the matching option at runtime |
| Free-text survey/option copy | `discover` first option, or tap first list item in a section |

**Authoring flow (after execution):**
1. **Discover** - from the dump during the run; bind `vars.*`.
2. **Act** - `${vars.*}` or stable selectors.
3. **Assert** - `intent` + grep/dump pattern; add `vlm:` only where the dump was insufficient.
4. **Record** - `discovered:` for the report audit.

If a value appears only in `discovered:` and never in `vars:` bindings, the test is portable.

### Known deadlock patterns

Maintain a per-app table (in your test plan or a project note) mapping a UI symptom to the code-backed fix, so future runs resolve it fast. When you resolve a new deadlock, add a row **and** update the spec's `test-plan.md`.

### Figma comparison (UI-change specs)

When the task verifies **UI changes** and a Figma link is available:
- Fetch design frames via the Figma MCP; capture matching emulator screenshots (helper-shrunk <=540).
- Record a side-by-side comparison in the report (assisted review - layout/component/spacing; not pixel-perfect).
- Skip for purely functional specs with no design delta.

## Phase 4 - Teardown (always run)

After all scenarios (or a destructive scenario):

1. **Restore state** - undo reversible setup.
2. **Exit the app:** Android `adb shell am force-stop <package_id>` / iOS `xcrun simctl terminate <UDID> <bundle_id>`.
3. Record restore success in the report.

## Improving test plans

When authoring or updating a spec's `test-plan.md`, each E2E scenario should include:
- **Code reference** (file + condition)
- **Account/state precondition** and **setup steps** if state must be prepared
- **Exact UI strings** (each locale in config)
- **Negative gate** - what the agent should see when the precondition fails (stop, don't guess coordinates)
