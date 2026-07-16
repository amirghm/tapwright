#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: memory-path.sh <android|ios> <package-or-bundle-id>" >&2
  exit 2
fi

platform="$1"
app_id="$2"

case "$platform" in
  android|ios) ;;
  *) echo "memory-path: platform must be android or ios" >&2; exit 2 ;;
esac

if [[ ! "$app_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "memory-path: invalid package or bundle id" >&2
  exit 2
fi

root="${TAPWRIGHT_MEMORY_ROOT:-.tapwright-memory}"
memory_dir="$root/$platform/$app_id"
graph="$memory_dir/app-map.yaml"

mkdir -p "$memory_dir"

if [[ ! -f "$graph" ]]; then
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$graph" <<EOF
schema_version: 1
app:
  platform: $platform
  id: $app_id
  versions: []
created_at: $now
updated_at: $now
nodes: {}
edges: []
gates: []
candidates: []
EOF
fi

printf '%s\n' "$graph"
