# E2E output conventions (`/test`)

**Read this** before emitting or interpreting files under a spec's `runs/` folder.

Related templates:
- `e2e-dsl.yaml` - per-scenario step format
- `e2e-patterns.yaml` - discovery patterns and intent assertions
- `test-report.md` - `/test` run summary

---

## What lives in a spec's `runs/` folder

**Only run data.** No docs here - conventions live in this file.

```
specs/<SPEC>/
├── test-plan.md
└── runs/
    ├── android/
    │   └── YYYY-MM-DDTHH-mm-ssZ/
    │       ├── test-report.md
    │       ├── e-1-<slug>.dsl.yaml
    │       └── resources/
    └── ios/
        └── YYYY-MM-DDTHH-mm-ssZ/
            ├── test-report.md
            ├── e-1-<slug>.dsl.yaml
            └── resources/
```

A `/test --android --ios` session uses the **same `run_id`** under both `runs/android/` and `runs/ios/`.

---

## Run ID

Generated at the **start** of each `/test` execution (UTC, filesystem-safe):

```
YYYY-MM-DDTHH-mm-ssZ
```

Example: `2026-07-15T15-05-00Z`

All artifacts go inside `runs/<platform>/<run_id>/` where `<platform>` is `android` or `ios`.

---

## Per-run artifacts

| File | Purpose |
|---|---|
| `test-report.md` | Full `/test` summary - start here |
| `e-<n>-<slug>.dsl.yaml` | Machine-readable steps for one scenario |
| `resources/` | Screenshots (PNG, <=540 long-edge + `.meta`) and UI dumps (XML/JSON) |

Screenshot paths in DSL are **relative to the run folder**: `resources/<file>.png`.

---

## Multiple runs

- Each `/test` creates artifacts under `runs/<platform>/<run_id>/`.
- Re-running creates a **new** `run_id` (or reuses the same `run_id` for the other platform in a dual-platform session).
- Compare runs by diffing `test-report.md` or `discovered:` blocks.
- Latest run = newest folder name (sortable ISO timestamp).

---

## Execution order (during `/test`)

1. Dump → grep → tap → **batch** taps with `sleep` (one Shell call when headless).
2. Assert from the dump; VLM only on a checkpoint PNG if the dump is insufficient.
3. Stuck after 2 taps → check app source when available; otherwise recover from
   the live UI and update the App Map.
4. **After** the scenario → write DSL. After the full run → `test-report.md` + teardown.

---

## Platform

| Platform | Output path | Command | id recorded |
|---|---|---|---|
| Android | `runs/android/<run_id>/` | `/test SPEC` | `android.package_id` |
| iOS | `runs/ios/<run_id>/` | `/test SPEC --ios` | `ios.bundle_id` |

iOS visibility: **visible by default**, `--headless` for background `simctl`+`idb` only.

Record `meta.platform` in DSL. iOS UI dumps use `idb ui describe-all` (JSON), not Android XML.

---

## Dynamic data rule

Do **not** hardcode volatile UI content in DSL steps (dates, amounts, dynamic copy). Use `discover` → `vars` → `assert(intent)`. See the `test-engine` skill and `e2e-patterns.yaml`.

Record resolved values under `discovered:` for the report - audit only, not replay inputs.

---

## Figma comparison (UI-change tasks only)

When the spec verifies visual UI changes and a Figma URL is available:
- Fetch the design via the Figma MCP; capture matching emulator/simulator screenshots.
- Add a comparison table to `test-report.md` (assisted review - not pixel-perfect).
- Skip for purely functional specs with no design delta.
