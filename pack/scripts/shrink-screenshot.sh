#!/usr/bin/env bash
# Shrink a checkpoint PNG in-place for cheaper VLM / faster I/O.
# Usage: shrink-screenshot.sh PATH_TO_PNG [MAX_EDGE]
# Writes sibling PATH_TO_PNG.meta with orig/out sizes and scale factors.
# Taps must still come from UI dump / AX - use .meta only if mapping image coords:
#   tap_x = image_x * scale_x ; tap_y = image_y * scale_y
#
# Requires: sips (macOS). On Linux, install a `sips` shim or swap in ImageMagick
# (`mogrify -resize 540x540`) - the .meta contract stays the same.
set -euo pipefail

path="${1:-}"
max_edge="${2:-540}"

if [[ -z "$path" || ! -f "$path" ]]; then
  echo "shrink-screenshot: missing file: ${path:-<empty>}" >&2
  exit 1
fi

meta="${path}.meta"

read_dim() {
  # sips -g pixelWidth file → "  pixelWidth: 1206"
  sips -g "$1" "$path" 2>/dev/null | awk -F': ' "/$1/ {print \$2; exit}"
}

orig_w="$(read_dim pixelWidth || true)"
orig_h="$(read_dim pixelHeight || true)"

if [[ -z "${orig_w:-}" || -z "${orig_h:-}" ]]; then
  echo "shrink-screenshot: warning: could not read dimensions for $path; leaving as-is" >&2
  exit 0
fi

long_edge="$orig_w"
if (( orig_h > orig_w )); then
  long_edge="$orig_h"
fi

if (( long_edge > max_edge )); then
  if ! sips -Z "$max_edge" "$path" >/dev/null 2>&1; then
    echo "shrink-screenshot: warning: sips failed for $path; leaving full-res" >&2
    printf 'orig_w=%s orig_h=%s out_w=%s out_h=%s scale_x=1 scale_y=1\n' \
      "$orig_w" "$orig_h" "$orig_w" "$orig_h" >"$meta"
    exit 0
  fi
fi

out_w="$(read_dim pixelWidth || true)"
out_h="$(read_dim pixelHeight || true)"
if [[ -z "${out_w:-}" || -z "${out_h:-}" ]]; then
  out_w="$orig_w"
  out_h="$orig_h"
fi

# awk for float scale (orig/out)
scale_x="$(awk -v o="$orig_w" -v n="$out_w" 'BEGIN { if (n+0==0) print 1; else printf "%.6f", o/n }')"
scale_y="$(awk -v o="$orig_h" -v n="$out_h" 'BEGIN { if (n+0==0) print 1; else printf "%.6f", o/n }')"

printf 'orig_w=%s orig_h=%s out_w=%s out_h=%s scale_x=%s scale_y=%s\n' \
  "$orig_w" "$orig_h" "$out_w" "$out_h" "$scale_x" "$scale_y" >"$meta"
