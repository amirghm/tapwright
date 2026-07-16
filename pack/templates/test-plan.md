# [Feature Name] - Test Plan

> Spec: <SPEC>

A `/test` run reads the **E2E Tests** section below and executes each scenario on a device.
Keep scenarios concrete: name the exact UI strings, the account state, and the negative gate
(what the agent should see if a precondition is not met, so it stops instead of guessing).

## Test Accounts

| Account | State / precondition | Purpose |
|---|---|---|
| [email or "existing session"] | [logged in / specific state] | [what this account tests] |

> Reference `accounts.*` from `tapwright.config.yml` where possible. Never put passwords here.

## E2E Tests

### E-1 - [scenario name]

| Field | Value |
|---|---|
| Surface | [screen / flow] |
| Entry | [how to reach it - tab, deep link] |
| Precondition | [account/app state required] |
| Code reference | [file + condition, App Map route, or live-only] |
| Strings (per locale) | [exact labels the agent should grep for] |
| Steps | 1. ... 2. ... 3. ... |
| Assert | [what proves pass - text/pattern/intent] |
| Negative gate | [what the agent sees if the precondition fails → blocked] |
| Setup | [steps to prepare state, if any] |
| Teardown | [reversible setup to undo] |

### E-2 - [scenario name]

_(repeat the table)_

## Verification checklist

- [ ] E-1
- [ ] E-2
