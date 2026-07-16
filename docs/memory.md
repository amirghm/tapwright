# App memory

tapwright builds a small App Map for every app it works with:

```text
.tapwright-memory/<platform>/<package-or-bundle-id>/app-map.yaml
```

Android and iOS memories are separate, even when both apps use the same ID. The
map is shared by coding agents working in the same repo. It is stored as a graph
of screens and the paths between them.

## What it remembers

- screens and stable text markers
- useful controls and accessibility/resource identifiers
- successful transitions between screens
- login, permission, feature, and state gates
- app versions where observations were verified
- success/failure counts, confidence, and last verification time

The App Map does not store screenshots, raw UI dumps, coordinates, passwords,
tokens, personal data, or dynamic account content.

## How every task uses it

1. Resolve the platform and package or bundle ID.
2. Create the App Map if this is the first task for the app.
3. Read the map before searching source code or exploring the UI.
4. If a complete route exists and its start markers match, use it directly and
   skip source inspection.
5. Search code only for missing, stale, low-confidence, version-mismatched, or
   conflicting parts of the route, and only when source code is available.
6. Validate every remembered screen and target against the live UI.
7. Merge newly verified nodes, edges, and gates after the task.
8. Record failed remembered paths so confidence can fall instead of repeating a
   bad route.

Memory guides execution but never overrides the live accessibility tree or UI
dump. An app update, locale, account state, feature flag, or experiment can make
an old path stale.

No source code or Git repo is required. In a standalone folder, tapwright can
build the App Map entirely from the foreground app, accessibility tree, UI dumps,
and verified interactions.

## Graph shape

```yaml
schema_version: 1
app:
  platform: android
  id: com.example.app
  versions: [2.4.0]
created_at: 2026-07-16T10:00:00Z
updated_at: 2026-07-16T10:05:00Z
nodes:
  home:
    markers: [Home]
    targets:
      account_tab:
        role: tab
        labels: [Account]
        resource_ids: [com.example.app:id/account]
    first_seen: 2026-07-16T10:00:00Z
    last_seen: 2026-07-16T10:05:00Z
edges:
  - from: home
    via: account_tab
    to: account
    requires: [logged_in]
    hits: 3
    misses: 0
    confidence: high
    last_verified: 2026-07-16T10:05:00Z
gates:
  - at: account
    signal: Sign in
    effect: login_required
    last_seen: 2026-07-16T10:02:00Z
```

Keep node IDs short and stable. Prefer labels, roles, resource IDs, accessibility
IDs, and semantic test IDs. Do not remember screen coordinates.

## Merge rules

- Store only screens and controls that helped a real request. Do not catalog the
  entire UI tree.
- Treat `from + via + to + requires` as an edge identity and update it instead of
  appending duplicates.
- Increase `hits` only after the destination markers are verified.
- Increase `misses` when a remembered target or destination does not match.
- Use `high` confidence for repeatedly verified routes with no recent misses,
  `medium` for a newly verified route, and `low` for stale or failed routes.
- Keep the map compact. Merge duplicate labels and IDs, and remove volatile text.
- For a large map, search task keywords and load only the connected subgraph
  needed for the current request.

## Sharing

The memory contains app structure rather than run evidence, so it can be
committed to the repo and shared with a team. Add `.tapwright-memory/` to
`.gitignore` when you want local-only memory.
