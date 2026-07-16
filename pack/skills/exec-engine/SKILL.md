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

Orchestrates `/exec`: **App Map → live UI → source fallback → chat summary**.

**Device skills (do not duplicate recipes):**
- Android: `device-interaction`
- iOS: `device-interaction-ios`

**Workflow:** `exec.md`

**Config:** read `tapwright.config.yml` for source globs, package/bundle ids, launch/build commands, accounts, and `known_flows`. If absent, use built-in glob defaults and parse ids from the sentence (see `config-reference.md`).

**App Memory:** initialize and read
`.tapwright-memory/<platform>/<package-or-bundle-id>/app-map.yaml` before source
digging. Prefer a remembered route when its markers match the live UI. After the
task, merge verified screens, transitions, gates, hits, misses, confidence, and
timestamps. Put source/config discoveries in `candidates` until the live UI
verifies them. Never store coordinates, secrets, personal data, or dynamic content.

```bash
export TAPWRIGHT_MEMORY="$(pack/scripts/memory-path.sh <platform> <app-id>)"
```

```powershell
$env:TAPWRIGHT_MEMORY = & "pack/scripts/memory-path.ps1" -Platform <platform> -AppId <app-id>
```

## Operating principles

1. **Map, then live UI** - use a matching App Map route first; discover missing
   steps from the running app. Read source only when a live target cannot be
   resolved.
2. **Execute, don't narrate** - brief once, then silent run until the summary (or blocked).
3. **Speed** - batch taps; short sleeps; dump sparingly; VLM only when the dump/AX tree is empty.
4. **Plan-driven dumps** - grep the dump for planned needles only; don't re-explore the whole tree each time.
5. **Learn once** - reuse verified App Map routes and update them after every task.

## Natural-language parsing

| Slot | Trigger words | Default |
|---|---|---|
| **Platform** | android, emulator / ios, simulator | Android |
| **Speed** | fast, asap, headless, background | fast when said; else Android batch / iOS visible |
| **Credentials** | "log in as ...", "password ..." | existing session, or `accounts.default` from config |
| **Task** | remaining verbs/objects | required |

If the **task** is missing or ambiguous, ask one question, then proceed.

## Phase 0 - App Map → step plan

**Before any tap**, read the App Map and turn matching verified edges into the
step plan. If the route is incomplete, launch the app and inspect the live UI.
Do not read source yet. Use source only after the map, one UI dump, and one
targeted scroll cannot resolve the next action.

## Source fallback for an unresolved target

Only after live resolution fails, derive a small source search from the sentence:

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
   On Android, enter all text with `type_text` from `adb-helpers.sh`. Never build
   `%s`-escaped `adb shell input text` commands, especially for long prompts.
4. Sleeps: **0.3-1s** tap-to-tap; **3-4s** after launch / login / save / network.
5. Scroll once if a needle is missing. Then micro-grep source when available, or
   inspect nearby stable live targets when it is not; retry once.
6. Verify **only** the plan's final success signal from the dump.
7. VLM/screenshot: **only** if the dump has no usable labels - capture via the `screenshot` helper (`adb-helpers.sh` / `ios-helpers.sh`, <=540 long-edge). Never tap from the shrunk PNG when dump/AX has bounds.
8. Update the App Map with verified nodes and edges. Record a miss or gate when
   a remembered path failed; do not save guessed paths.

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
| Prep | App Map + targeted dig if needed | App Map + targeted verification |
| Artifacts | Optional `.tapwright-run/<date>/<time>-automate/` scratch evidence | DSL + report + resources |
