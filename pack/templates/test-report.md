---
spec: <SPEC>
run_id: YYYY-MM-DDTHH-mm-ssZ
executed_at: YYYY-MM-DDTHH:mm:ssZ
executed_by: agent
result: pass | fail | partial | blocked
test_plan: specs/<SPEC>/test-plan.md
---

# Test Report - <SPEC>

> Run `{{run_id}}`, {{executed_at}}, **{{result}}**

## Summary

| Field | Value |
|---|---|
| Spec | <SPEC> |
| Platform | android / ios (`/test` or `/test --ios`) |
| App id | `com.example.app` (android.package_id / ios.bundle_id) |
| Environment | staging |
| Device | Android: `emulator-5554`, iOS: simulator UDID + name |
| Simulator visibility | visible (default), headless (`--headless`) - iOS only |
| Account | `qa@example.com` (or existing session) |
| Scenarios run | N / N |
| Pass | N |
| Fail | 0 |
| Blocked | 0 |
| Teardown | State restored, app stopped |
| Figma comparison | N/A - functional verification only |

## Scenario results

| ID | Surface | Result | Checks | Screenshots | DSL |
|---|---|---|---|---|---|
| E-1 | <surface> | pass | A-pos, A-neg | [e1](resources/e1.png) | [dsl](e-1-<slug>.dsl.yaml) |

## Discovered at runtime

Values resolved during execution (audit - not hardcoded in steps):

| Variable | E-1 | E-2 |
|---|---|---|
| `<var>` | - | - |

## How it was tested

1. **Phase 0** - Verified navigation, gates, and string keys in the app source.
2. **Device** - `<device>`, `<account/session>`.
3. **Execution** - dump → grep → tap; discover → vars → intent assertions (no hardcoded volatile values).
4. **Teardown** - State restored; app stopped.

## Blockers / notes

- _(none)_

## Figma design comparison

<!-- Include only when the task verifies UI changes and a Figma URL is available. -->

| Screen | Figma node | Device screenshot | Comparison | Result |
|---|---|---|---|---|
| - | - | - | - | N/A |

## Artifacts in this run

See `pack/templates/e2e.md` for the full layout convention.

```
specs/<SPEC>/runs/{{platform}}/{{run_id}}/
├── test-report.md          ← this file
├── e-1-*.dsl.yaml
└── resources/              ← PNG checkpoints (<=540 + .meta) + UI dumps
```

(`{{platform}}` = `android` or `ios`)
