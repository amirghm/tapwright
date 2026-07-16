---
name: test-engine
description: |
  Mobile test-plan execution engine for tapwright. Use this skill whenever:
  - The user runs `/test SPEC`, `/test SPEC --ios`, or `/test SPEC --ios --headless`, or asks to execute a mobile test plan on an emulator/simulator.
  - You need to verify E2E scenarios against an App Map, live app, or available source before driving adb or idb.
  - You are writing or improving a spec's `test-plan.md` with agent-executable steps.
  - The user mentions test execution, e2e DSL, or running staging/QA verification on a device.
  ALWAYS read this skill before executing `/test`. Use App Memory before source inspection.
---

# Test Engine

Orchestrates `/test`. First plan from the App Map, inspect source only for gaps
or stale/conflicting memory, post a short execution brief, then execute
immediately. `/test` is a run command; do not wait for a second confirmation.

**Platform skills:**
- Android (default): `device-interaction`
- iOS (`--ios`): `device-interaction-ios`

**Config:** `tapwright.config.yml` supplies source globs, package/bundle ids, build/launch commands, accounts, and `known_flows`.

**Output conventions:** read `pack/templates/e2e.md` before writing anything under `specs/<SPEC>/runs/`.

**App Memory:** initialize and read
`.tapwright-memory/<platform>/<package-or-bundle-id>/app-map.yaml` before any
source inspection. Use a complete remembered route directly when its start
markers match the current UI. After execution, merge verified nodes, edges, gates, app versions,
hits, misses, confidence, and timestamps. Do not store coordinates, secrets,
personal data, or dynamic content.

Creating or editing a test plan is itself an App Memory update. Before any run,
merge its new scenario intents, expected routes, markers, and gates into
`candidates` as `unverified`, with the test-plan reference and timestamp. For a
cross-platform plan, update each configured app ID separately. Do not promote
candidate edges until a live run verifies their destination markers.

```bash
export TAPWRIGHT_MEMORY="$(pack/scripts/memory-path.sh <platform> <app-id>)"
```

```powershell
$env:TAPWRIGHT_MEMORY = & "pack/scripts/memory-path.ps1" -Platform <platform> -AppId <app-id>
```

## Phase 0 - App Map and targeted verification

Read matching App Map routes first. When a complete route covers a scenario and
its start-screen markers match the live UI, use it without reading source code.
For missing, stale, low-confidence, version-mismatched, or conflicting parts,
trace only the affected section in the real app source when source is available.
Without source, derive the same information from the App Map, test plan, and
live UI. Missing source is not a blocker. Run the following checks only where
source files exist:

1. **Find the UI surface** - grep `string_globs` and screen definitions for the labels the scenario names.
2. **Find entry navigation** - read files matched by `nav_globs`.
3. **Find gating conditions** - states/flags that enable or hide the control under test (e.g. an item is only editable in a certain status).
4. **Find exact string keys** - in the string-resource files (check each locale in `tapwright.config.yml`).
5. **Note layout differences** - list vs chips, bottom sheet vs full screen, differing CTAs.

Document findings in a short **Execution brief** (format below). If the test plan contradicts the code, **update the test plan** or flag the gap to the user.

### Gates (generic)

A "gate" is any code condition that must hold for a step to be reachable. When a gate fails, the UI shows a different state - the agent must **stop and report blocked**, never guess coordinates. Record the gates you find per scenario so the run can recognize them in the dump. Encode recurring preconditions as `known_flows` setup steps in config.

## Phase 1 - Execution brief (mandatory before actions)

Use a read-only UI dump to check the remembered start markers when needed.
Produce this brief in chat, then **start device actions immediately** - no
approval gate:

```markdown
## /test <SPEC> - Execution brief

### Platform
- android (default) | ios (`--ios`)
- iOS visibility: `visible` (default) | `headless` (`--headless`)

### Route summary
- [E-1] Source: App Map | targeted code check | Entry: ... | Gate: ... | Strings: ...
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

When source exists, grep strings, navigation, and gates, then resume with
code-backed labels. Without source, re-dump, inspect nearby stable targets, and
promote the verified route to the App Map. No VLM unless the dump is still
ambiguous.

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

Maintain a per-app table mapping a UI symptom to the verified App Map or
code-backed fix, so future runs resolve it fast. When you resolve a new deadlock,
update the App Map and the spec's `test-plan.md`.

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

## Phase 5 - Update App Memory

Merge only what this run verified into the same App Map. Increase hits for paths
that worked. Increase misses and reduce confidence for remembered paths that did
not match the current app. Add newly observed gates, app versions, and timestamps
even when a scenario was blocked. Never copy coordinates, raw dumps, screenshots,
credentials, or dynamic test data into memory.

When a run verifies an unverified test candidate, promote it to nodes/edges and
remove the candidate. When it fails or is blocked, update the candidate status
and stable reason so the next run does not repeat the same assumption.

## Improving test plans

When authoring or updating a spec's `test-plan.md`, each E2E scenario should include:
- **Code reference** (file + condition) when source exists; otherwise the App
  Map route or live-only note
- **Account/state precondition** and **setup steps** if state must be prepared
- **Exact UI strings** from source or verified live markers
- **Negative gate** - what the agent should see when the precondition fails (stop, don't guess coordinates)
