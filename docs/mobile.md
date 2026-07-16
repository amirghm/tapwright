# `@mobile`

`@mobile` is the main tapwright experience.

Use it when you want a coding agent to build or change a mobile app, interact
with it, debug it, or turn a repeated flow into a test. V1 is just Markdown
instructions, templates, and shell helpers. It is not a runtime, SDK, daemon, or
hosted service.

`@mobile` is executable. The agent should perform the work in the current
workspace and verify it on mobile, not return a prompt for another agent. Prompt
generation happens only when you explicitly ask for `prompt-only` or say `do not
implement`.

## Examples

```text
@mobile build a daily planner and verify its main flow
@mobile fix the checkout screen and test it on Android
@mobile what screen is my app showing?
@mobile log in with the QA account and find billing
@mobile check if a new user can skip onboarding
@mobile open the latest order and see if refund is available
@mobile find where the app asks for notification permission
@mobile debug why login is stuck
@mobile record the onboarding flow so we can make it a test
@mobile compare this screen with the design
```

## Development examples

```text
@mobile test the profile changes I just made
@mobile run the checkout plan on Android
@mobile run the checkout plan on iOS, visible, so I can watch
@mobile run CHECKOUT on both Android and iOS
@mobile run only E-2 from the checkout plan
@mobile record this reset-password flow as a test plan
```

For planned test runs, use `specs/<NAME>/test-plan.md`. The agent writes each run under
`specs/<NAME>/runs/` with a report, useful screenshots, and replayable steps.

## Modes

You can still use explicit modes when you want them:

| Mode | Use it for |
|---|---|
| `build` | Implement app changes, build/launch, verify on device, and iterate |
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

1. Execute the request; for build/change work, edit the app first.
2. Read the App Map and use a complete matching route directly.
3. Check source only for gaps when source exists.
4. Dump the live UI tree and validate every action.
5. Tap, type, and swipe from real element bounds.
6. Use screenshots for evidence or fallback.
7. Fix issues and repeat, or stop on a real gate.

## App Memory

Every task reads and updates an App Map stored by platform and package or bundle
ID. Verified screens and routes help later agents plan with less exploration,
which improves accuracy and reduces token usage. The live UI is still checked
before every remembered action.

A complete matching route skips source inspection. If the map has gaps,
tapwright checks source when it is available or learns the missing path from the
live UI when it is not. A repo is helpful, not required.

New or edited tests and other stable app data are saved as unverified candidates
immediately. A live run promotes them into trusted routes or records why they
failed.

See [memory.md](memory.md) for the map structure and safety rules.

## Platforms

- Android: `adb` + UIAutomator on emulators by default.
- iOS: `simctl` + `idb` on Simulators by default.
- Physical devices are allowed only after explicit user confirmation.

## Artifacts

- `@mobile test` writes reports/DSL/resources under
  `specs/<SPEC>/runs/<platform>/<run_id>/`.
- Other modes may write scratch evidence under
  `.tapwright-run/<YYYY-MM-DD>/<HH-mm-ssZ>-<mode>/` when useful. Every request
  gets a separate UTC-dated folder, and all evidence for that request stays
  together.
- Simple automation can remain chat-only.
- App Memory is persistent and separate from run evidence.

## Compatibility

Use `@mobile` in normal chat. If your coding tool does not recognize it, use
`/mobile` instead. Both route to the same workflow.

The helper skill is named `mobile-engine` so command pickers do not show two
different `mobile` entries.

The installer adds plain Markdown plus a few agent-specific files where it can,
so the same idea works across Codex, Claude Code, Cursor, OpenCode, Copilot, and
similar tools.
