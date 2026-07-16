---
name: exec-engine
description: |
  Natural-language mobile task execution for tapwright. Use this skill whenever:
  - The user runs `/exec ...` with a plain-English task on a mobile app.
  - You need to parse NL intent (log in, navigate, toggle, complete a flow) and drive adb/idb.
  - The user asks for ad-hoc emulator/simulator actions without a test plan.
  ALWAYS read this skill before `/exec`. Output is chat-first, with timestamped
  scratch evidence only when needed.
  Structured spec runs: use the `test-engine` skill + `/test` instead.
---

# Exec Engine

Orchestrates `/exec`: **dig → step plan → fast execute → chat summary**.

**Device skills (do not duplicate recipes):**
- Android: `device-interaction`
- iOS: `device-interaction-ios`

**Workflow:** `exec.md`

**Config:** read `tapwright.config.yml` for source globs, package/bundle ids, launch/build commands, accounts, and `known_flows`. If absent, use built-in glob defaults and parse ids from the sentence (see `config-reference.md`).

## Operating principles

1. **Dig before tap** - grep the app source (`string_globs` + `nav_globs`) for labels + navigation; build a numbered step plan with label needles.
2. **Execute, don't narrate** - brief once, then silent run until the summary (or blocked).
3. **Speed** - batch taps; short sleeps; dump sparingly; VLM only when the dump/AX tree is empty.
4. **Plan-driven dumps** - grep the dump for planned needles only; don't re-explore the whole tree each time.

## Natural-language parsing

| Slot | Trigger words | Default |
|---|---|---|
| **Platform** | android, emulator / ios, simulator | Android |
| **Speed** | fast, asap, headless, background | fast when said; else Android batch / iOS visible |
| **Credentials** | "log in as ...", "password ..." | existing session, or `accounts.default` from config |
| **Task** | remaining verbs/objects | required |

If the **task** is missing or ambiguous, ask one question, then proceed.

## Phase 0 - Code dig → step plan (mandatory)

**Before any tap**, grep in parallel (and parallel with boot/launch), using globs from config:

```text
# from tapwright.config.yml → string_globs
**/res/values*/strings.xml
**/composeResources/values*/strings.xml
**/*.xcstrings
**/locales/**/*.json
# from tapwright.config.yml → nav_globs
**/*Navigation*.kt   **/*NavGraph*.kt   **/*Routes*.*
```

Grep those files for the words in the task to find exact label strings (and their keys), then expand to a **step plan**:

| # | Screen | Action | Dump needles (per locale) | Success |
|---|---|---|---|---|
| 1 | ... | tap/type/scroll | exact strings from dig | next title / gate |

Include every locale variant the app might show (from `locales`). Keep the plan in memory - **no repo files**.

Re-dig mid-run only after **2 failed taps** on the same step.

## Intent → dig-hint mechanism (generic)

tapwright ships **no** app-specific intent table. Derive dig hints from the sentence:

1. **Extract keywords** from the task ("log in", "settings", "notifications", "checkout", "cancel").
2. **Grep `string_globs`** for those keywords (and obvious synonyms) → collect matching label strings + resource keys.
3. **Grep `nav_globs`** for the screen/route names near those labels → establish screen order.
4. **Check `known_flows`** in config: if a flow matches the intent, use its steps directly (still verify each against the live dump).
5. **Build the step plan** from the intersection: entry tab → intermediate screens → target action → confirm.

Teams encode their recurring journeys as `known_flows` in `tapwright.config.yml` (the portable, per-app replacement for hardcoded recipes). Example shape:

```yaml
known_flows:
  reset_onboarding:
    - { screen: Home, action: tap, needles: [Menu], success: Settings }
    - { screen: Settings, action: scroll }
    - { action: tap, needles: [Reset onboarding], success: Are you sure }
    - { action: confirm, needles: [Confirm, Yes], success: Welcome }
```

### Gate handling (stop - don't guess)

If the dump shows a state that blocks the plan (a disabled control, a "not available" message, the wrong screen after 2 taps), **stop and report blocked** with the gate text + a dump snippet. Never fall back to random coordinates.

## Execution loop (maximize speed)

1. Launch (reuse install/session when possible).
2. Dismiss blockers immediately via dump labels (OS permission dialogs, ATT, notification sheets, "Allow"/"Don't Allow").
3. For each plan step: dump → grep needles → tap center → batch next 2-5 in the same Shell when safe.
4. Sleeps: **0.3-1s** tap-to-tap; **3-4s** after launch / login / save / network.
5. Scroll once if a needle is missing; then micro-grep source; retry once.
6. Verify **only** the plan's final success signal from the dump.
7. VLM/screenshot: **only** if the dump has no usable labels - capture via the `screenshot` helper (`adb-helpers.sh` / `ios-helpers.sh`, <=540 long-edge). Never tap from the shrunk PNG when dump/AX has bounds.

### Login (fast)

- Android: dump → tap Sign in/Log in → email field → password → ENTER → sleep 4 → dump home.
- iOS: `idb ui text` into fields; tap the Sign in button.
- Password from `accounts.<name>.password_env` (read the env var); never echo it.

### Batching

| Mode | Shell batching | Pause |
|---|---|---|
| Android / iOS fast | 2-5 steps per call | short |
| iOS visible | 1-2 steps; user can watch | ~3s |

## Security

- Never write passwords to the repo, reports, or shell history files.
- Brief + summary: **email only**, no password.

## Chat summary template (final message only)

```markdown
## /exec result

- **Task:** ...
- **Platform:** android | ios (visible | headless)
- **Account:** email or "existing session" (no password)
- **Result:** done | failed | blocked

### What was done
- ...

### Final UI state
...

### Teardown
App stopped. State restored: yes | no | n/a

### Notes
Blockers / follow-ups only if needed.
```

## vs `/test`

| | `/exec` | `/test` |
|---|---|---|
| Input | Natural language | a spec's `test-plan.md` |
| Prep | Focused dig → step plan | Full verification |
| Artifacts | Optional `.tapwright-run/<date>/<time>-automate/` scratch evidence | DSL + report + resources |
