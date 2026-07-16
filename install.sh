#!/usr/bin/env bash
# tapwright installer - copy the agent pack into your app repo.
#
# Usage (run from your app repo root, or pass --dest):
#   /path/to/tapwright/install.sh                 # auto-detect agent dir
#   /path/to/tapwright/install.sh --agent-dir .claude
#   /path/to/tapwright/install.sh --dest /path/to/app-repo
#
# Installs into <AGENT_DIR>/{workflows,skills,scripts,templates}/ where AGENT_DIR is
# one of .cursor, .claude, or .agents. Paths inside the copied skills/workflows are
# rewritten to point at the chosen AGENT_DIR so `source .../scripts/*.sh` resolves.
# Also adds idempotent instruction/adaptor blocks for `@mobile` and `/mobile`.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PACK="$SRC_DIR/pack"

DEST="$(pwd)"
AGENT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="$2"; shift 2;;
    --agent-dir) AGENT_DIR="$2"; shift 2;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ ! -d "$PACK" ]]; then
  echo "install: cannot find pack/ next to install.sh ($PACK)" >&2
  exit 1
fi

cd "$DEST"

# Auto-detect the agent dir if not forced.
if [[ -z "$AGENT_DIR" ]]; then
  if   [[ -d .cursor ]]; then AGENT_DIR=".cursor"
  elif [[ -d .claude ]]; then AGENT_DIR=".claude"
  else AGENT_DIR=".agents"
  fi
fi

echo "tapwright: installing into $DEST/$AGENT_DIR"
mkdir -p "$AGENT_DIR/workflows" "$AGENT_DIR/skills" "$AGENT_DIR/scripts" "$AGENT_DIR/templates"

cp -R "$PACK/workflows/." "$AGENT_DIR/workflows/"
for skill_dir in "$PACK/skills"/*; do
  [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
  cp -R "$skill_dir" "$AGENT_DIR/skills/"
done
cp -R "$PACK/scripts/."   "$AGENT_DIR/scripts/"
cp -R "$PACK/templates/." "$AGENT_DIR/templates/"
chmod +x "$AGENT_DIR/scripts/"*.sh 2>/dev/null || true

# Rewrite intra-pack paths (pack/scripts/... , pack/templates/...) to the install dir.
# Portable in-place sed across BSD/GNU.
sed_i() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }
while IFS= read -r f; do
  sed_i \
    -e "s#pack/scripts/#$AGENT_DIR/scripts/#g" \
    -e "s#pack/templates/#$AGENT_DIR/templates/#g" \
    "$f"
done < <(find "$AGENT_DIR/workflows" "$AGENT_DIR/skills" -type f -name '*.md')

refresh_marked_block() {
  local file="$1"
  local name="$2"
  local begin="<!-- tapwright:$name begin -->"
  local end="<!-- tapwright:$name end -->"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

append_agents_block() {
  local file="AGENTS.md"
  refresh_marked_block "$file" "mobile"
  cat >> "$file" <<EOF
<!-- tapwright:mobile begin -->

## tapwright mobile

Use tapwright when the user runs \`@mobile\` or \`/mobile\`, or asks for mobile app inspection, automation, manual UI testing, debugging, E2E execution, recording, replay, or screenshot/design comparison.

- Primary experience: \`@mobile\`.
- If the coding tool does not support \`@mobile\`, use \`/mobile\` instead.
- Read \`$AGENT_DIR/skills/mobile/SKILL.md\` before acting.
- \`@mobile\` controls the running app. If the user asks to create something inside an app, do it through that app's live UI; edit source only when explicitly requested.
- Route ad-hoc automation through \`$AGENT_DIR/skills/exec-engine/SKILL.md\`.
- Route E2E specs through \`$AGENT_DIR/skills/test-engine/SKILL.md\` and \`$AGENT_DIR/workflows/test.md\`.
- Use Android/iOS device recipes from \`$AGENT_DIR/skills/device-interaction*/SKILL.md\`.
- Before every task, read the per-app App Map under \`.tapwright-memory/<platform>/<app-id>/app-map.yaml\`; create it when missing and update it after the task.
- New tests and stable app data update map candidates immediately; only live-verified routes become trusted edges.
- Source code is optional. Use the App Map first, then the live UI; inspect source only when a target remains unresolved.
- Prefer emulators/simulators; ask before touching physical devices.
- Resolve UI targets from dumps/accessibility trees before screenshots or coordinates.

First useful request after install:

\`@mobile what screen is my app showing?\`

<!-- tapwright:mobile end -->
EOF
}

write_file_if_missing_or_tapwright_owned() {
  local file="$1"
  local marker="$2"
  local content="$3"
  mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]] && ! grep -q "$marker" "$file"; then
    echo "tapwright: left existing $file untouched"
    return 0
  fi
  printf "%s\n" "$content" > "$file"
}

install_agent_adapters() {
  append_agents_block

  if [[ "$AGENT_DIR" == ".claude" || -d .claude ]]; then
    mkdir -p .claude/commands
    write_file_if_missing_or_tapwright_owned \
      ".claude/commands/mobile.md" \
      "tapwright:generated" \
      "---"$'\n'"description: tapwright mobile for Android/iOS inspection, automation, manual testing, debugging, recording, replay, compare, and E2E."$'\n'"---"$'\n\n'"<!-- tapwright:generated -->"$'\n\n'"Read \`$AGENT_DIR/skills/mobile/SKILL.md\` and execute the rest as a mobile request. Control the running app; do not edit source unless explicitly requested."
  fi

  if [[ "$AGENT_DIR" == ".cursor" || -d .cursor ]]; then
    mkdir -p .cursor/rules
    write_file_if_missing_or_tapwright_owned \
      ".cursor/rules/tapwright-mobile.mdc" \
      "tapwright:generated" \
      "---"$'\n'"description: Use tapwright @mobile for mobile inspection, automation, manual testing, debugging, recording, replay, compare, and E2E."$'\n'"alwaysApply: false"$'\n'"---"$'\n\n'"<!-- tapwright:generated -->"$'\n\n'"When the user runs @mobile or /mobile, read \`$AGENT_DIR/skills/mobile/SKILL.md\`. Control the running app; do not edit source unless explicitly requested. Prefer emulators/simulators and ask before touching physical devices."
  fi

  if [[ -d .opencode ]]; then
    mkdir -p .opencode/agents
    write_file_if_missing_or_tapwright_owned \
      ".opencode/agents/mobile.md" \
      "tapwright:generated" \
      "---"$'\n'"description: tapwright mobile agent for Android/iOS inspection, automation, manual testing, debugging, recording, replay, compare, and E2E."$'\n'"---"$'\n\n'"<!-- tapwright:generated -->"$'\n\n'"Read \`$AGENT_DIR/skills/mobile/SKILL.md\`, then control the running app with the installed device skills. Do not edit source unless explicitly requested. Prefer emulators/simulators; ask before touching physical devices."
  fi

  if [[ -d .github ]]; then
    refresh_marked_block ".github/copilot-instructions.md" "mobile"
    cat >> ".github/copilot-instructions.md" <<EOF
<!-- tapwright:mobile begin -->

## tapwright mobile

For \`@mobile\`, \`/mobile\`, mobile app inspection, automation, debugging, manual UI testing, record/replay, compare, or E2E requests, read \`$AGENT_DIR/skills/mobile/SKILL.md\` and control the running app. Do not edit source unless explicitly requested. Prefer emulators/simulators and ask before interacting with physical devices.

<!-- tapwright:mobile end -->
EOF
  fi
}

# Seed a config if none exists yet.
if [[ ! -f tapwright.config.yml ]]; then
  cp "$SRC_DIR/config/tapwright.config.example.yml" tapwright.config.yml
  echo "tapwright: wrote starter tapwright.config.yml - edit it to describe your app"
else
  echo "tapwright: tapwright.config.yml already exists - left untouched"
fi

install_agent_adapters

cat <<EOF

Done. Installed:
  $AGENT_DIR/workflows/{exec.md,test.md}
  $AGENT_DIR/skills/{mobile,exec-engine,test-engine,device-interaction,device-interaction-ios}
  $AGENT_DIR/scripts/*.sh
  $AGENT_DIR/templates/*
  AGENTS.md tapwright mobile block

App Memory will be created per app under .tapwright-memory/ on the first request.

Best-effort adapters were added when matching agent folders existed:
  .claude/commands/mobile.md
  .cursor/rules/tapwright-mobile.mdc
  .opencode/agents/mobile.md
  .github/copilot-instructions.md

Next:
  1. Fill what you know in tapwright.config.yml. Source code is optional.
  2. Ask your agent: @mobile what screen is my app showing?
     If @mobile is not supported, use /mobile instead.
EOF
