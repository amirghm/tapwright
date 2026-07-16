# Writing a step plan

The step plan is tapwright's core idea: **before touching the device**, use the
App Map to produce a deterministic, numbered plan of what to tap and how to know
it worked. When the map has a gap, use source code if available or learn from the
live UI. This is what makes runs fast and reproducible instead of a
vision-guessing loop.

The agent builds this automatically during Phase 0 of `/exec` and `/test`. This doc explains
the shape so you can (a) understand what it's doing and (b) author `known_flows` yourself.

## Anatomy of a step

Each step answers four questions:

| Field | Question | Source |
|---|---|---|
| **Screen** | Where should I be right now? | screen title / a gate string |
| **Action** | What do I do? | `tap` / `type` / `scroll` / `key` / `confirm` |
| **Needles** | What text identifies the target? | App Map; source/live UI for gaps |
| **Success** | How do I know it worked? | text expected in the next dump |

## How the agent derives it

The agent checks the per-app App Map first. A complete route with matching live
screen markers can be used directly without reading source code. Missing steps
come from the live UI. Source is a fallback for unresolved targets.

When the App Map and live UI cannot resolve a target and source exists:

1. Extract keywords from the task or scenario ("account", "notifications", "checkout").
2. Grep `string_globs` for those words → collect the exact label strings + resource keys.
3. Grep `nav_globs` near those labels → establish the screen order.
4. Assemble: entry tab → intermediate screens → target action → confirmation.

Without source, the agent discovers the missing steps from stable labels and
identifiers in the live UI, verifies each transition, and adds them to the map.

When source exists, needles from real resource files match what the live UI dump
contains - so the agent taps element bounds, not guessed coordinates.

## Example (login)

```
1. Screen: Welcome        Action: tap    Needles: [Log in, Sign in]     Success: "Email"
2. Screen: Login          Action: type   Field: [Email]  Value: qa@example.com
3. Screen: Login          Action: type   Field: [Password]  Value: ${accounts.default.password}
4. Screen: Login          Action: key    Key: enter                     Success: "Home" | "Account"
```

## Encoding it as a `known_flow`

Put reusable journeys in `tapwright.config.yml` so the agent skips re-deriving them (it still
verifies each step against the live dump):

```yaml
known_flows:
  login:
    - { screen: Welcome, action: tap, needles: [Log in, Sign in], success: Email }
    - { action: type, field_needles: [Email], value: "${accounts.default.email}" }
    - { action: type, field_needles: [Password], value: "${accounts.default.password}" }
    - { action: key, key: enter, success: Home }
```

## Good needles vs bad needles

| Good | Bad |
|---|---|
| Exact resource strings ("Delivery details") | Paraphrases the agent invented |
| All locale variants you support | English only when the account is localized |
| Short, unique labels | Long sentences that wrap/truncate on screen |
| A stable gate word for `success` | A volatile value (date/price) as the success signal |

## When a step fails

The workflows retry a missing needle by scrolling once, then re-grepping the source, then
retrying once. After two failures on the same step the agent stops and reports **blocked**
with the gate text - it will not fall back to random taps. Fix the needle (or the config
globs) and re-run.
