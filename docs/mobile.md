# `@mobile`

`@mobile` is the main tapwright entrypoint.

Use it when you want a coding agent to look at a mobile app, interact with it,
debug it, or turn a repeated flow into a test. V1 is just Markdown instructions,
templates, and shell helpers. It is not a runtime, SDK, daemon, or hosted service.

## Examples

```text
@mobile what screen is my app showing?
@mobile log in with the QA account and find billing
@mobile check if a new user can skip onboarding
@mobile open the latest order and see if refund is available
@mobile find where the app asks for notification permission
@mobile debug why login is stuck
@mobile record the onboarding flow so we can make it a test
@mobile compare this screen with the design
```

## Modes

You can still use explicit modes when you want them:

| Mode | Use it for |
|---|---|
| `inspect` | Check the current device, app, screen, UI tree, and optional screenshot |
| `automate` | Complete a natural-language goal |
| `manual` | Work through a UI check one action at a time |
| `test` | Run a `test-plan.md` and write report + replayable DSL |
| `debug` | Gather a UI dump, screenshot, app state, and logs |
| `record` | Save performed actions as draft DSL |
| `replay` | Run an existing DSL or test flow |
| `compare` | Compare a screenshot with a design or reference image |

## How it works

The rule of thumb is simple:

1. Read app strings and navigation when planning a goal.
2. Dump the live UI tree.
3. Tap, type, and swipe from real element bounds.
4. Use screenshots for evidence or fallback.
5. Stop when the app is gated or in the wrong state.

## Platforms

- Android: `adb` + UIAutomator on emulators by default.
- iOS: `simctl` + `idb` on Simulators by default.
- Physical devices are allowed only after explicit user confirmation.

## Artifacts

- `@mobile test` writes reports/DSL/resources under
  `specs/<SPEC>/runs/<platform>/<run_id>/`.
- Other modes may write scratch evidence under `.tapwright-run/` when useful.
- Simple automation can remain chat-only.

## Compatibility

Some agents support literal `@mobile` mentions. Others use slash commands,
skills, rules, or repo instructions. The installer adds plain Markdown plus a few
agent-specific files where it can, so the same idea works across Codex, Claude
Code, Cursor, OpenCode, Copilot, and similar tools.
