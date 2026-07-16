#!/usr/bin/env bash
set -euo pipefail

mode="${1:-run}"
case "$mode" in
  build|inspect|automate|manual|debug|record|replay|compare|run) ;;
  *) mode="run" ;;
esac

root="${TAPWRIGHT_RUN_ROOT:-.tapwright-run}"
now_date="$(date -u +%Y-%m-%d)"
now_time="$(date -u +%H-%M-%SZ)"
parent="$root/$now_date"
run_dir="$parent/$now_time-$mode"
suffix=2

while [[ -e "$run_dir" ]]; do
  run_dir="$parent/$now_time-$mode-$suffix"
  suffix=$((suffix + 1))
done

mkdir -p "$run_dir/resources"
printf '%s\n' "$run_dir"
