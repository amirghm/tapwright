#!/usr/bin/env bash
# tapwright adb helpers - source from workflow shell blocks. No Python.
# Usage:
#   export SERIAL=emulator-5554      # target device (adb devices -l)
#   export PKG=com.example.app       # optional: your app's applicationId
#   source pack/scripts/adb-helpers.sh
#
# Functions: dump_ui, tap_text, type_text, screenshot, has_plus, assert_no_plus
#
# Resolve this file's directory when sourced (bash or zsh)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _TAPWRIGHT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _TAPWRIGHT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  _TAPWRIGHT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Dump the current view hierarchy to a local file.
dump_ui() {
  adb -s "$SERIAL" shell uiautomator dump /sdcard/window_dump.xml >/dev/null
  adb -s "$SERIAL" pull /sdcard/window_dump.xml "$1" >/dev/null
}

# Tap the center of the first node whose text/content-desc contains a needle (literal match).
#   tap_text <dump_file> <needle> [any|bottom|top]
# Set PKG to bias toward your app's nodes when a package attribute is present.
tap_text() {
  local dump_file="$1" needle="$2" prefer="${3:-any}"
  local coords
  coords=$(NEEDLE="$needle" PREFER="$prefer" PKG="${PKG:-}" perl -0777 -ne '
    my $needle = quotemeta($ENV{NEEDLE});
    my $pref   = $ENV{PREFER} || "any";
    my $pkg    = $ENV{PKG} || "";
    my @m;
    while (/(?:text|content-desc)="([^"]*$needle[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"(?:[^>]*package="([^"]*)")?/gi) {
      push @m, [$1,$2,$3,$4,$5,($6 // "")];
    }
    # Prefer nodes belonging to $pkg when we captured a package attribute.
    if ($pkg ne "") {
      my @pref = grep { $_->[5] eq $pkg } @m;
      @m = @pref if @pref;
    }
    exit 1 unless @m;
    if    ($pref eq "bottom") { @m = sort { $b->[4] <=> $a->[4] } @m; }
    elsif ($pref eq "top")    { @m = sort { $a->[4] <=> $b->[4] } @m; }
    my $t = $m[0];
    printf "%d %d %s\n", ($t->[1]+$t->[3])/2, ($t->[2]+$t->[4])/2, $t->[0];
  ' "$dump_file")
  [[ -z "$coords" ]] && return 1
  local x y label; read -r x y label <<< "$coords"
  echo "  tap '$label' ($x,$y)"
  adb -s "$SERIAL" shell input tap "$x" "$y"
  sleep "${STEP_PAUSE:-2}"
}

# Type ASCII text into the focused field without adb's fragile %s space escape.
# Pass text as one argument or through stdin. Words are sent separately and all
# whitespace becomes a space key event so a newline cannot submit the field.
# Unsupported Unicode fails before anything is sent.
type_text() {
  local text script
  if [[ $# -gt 0 ]]; then
    text="$1"
  else
    text="$(cat)"
  fi

  script="$(mktemp)"
  if ! TW_TEXT="$text" perl -e '
    use strict;
    use warnings;
    my $text = $ENV{TW_TEXT} // "";
    die "type_text: non-ASCII text requires a Unicode-capable device keyboard\n"
      if $text =~ /[^\x09\x0A\x0D\x20-\x7E]/;

    sub emit_text {
      my ($value) = @_;
      return if $value eq "";
      $value =~ s/\x27/\x27"\x27"\x27/g;
      print "input text \x27$value\x27\n";
    }

    for my $part (split(/(\r\n|\r|\n|[ \t])/, $text, -1)) {
      if ($part eq " " || $part eq "\t" || $part eq "\n" ||
          $part eq "\r" || $part eq "\r\n") {
        print "input keyevent 62\n";
      } else {
        # Keep percent signs separate so literal %s is never interpreted as a space.
        emit_text($_) for split(/(%)/, $part, -1);
      }
    }
  ' > "$script"; then
    rm -f "$script"
    return 2
  fi

  adb -s "$SERIAL" shell sh < "$script"
  local status=$?
  rm -f "$script"
  return "$status"
}

# Capture a full-res screenshot then shrink it in place (writes <file>.meta).
screenshot() {
  adb -s "$SERIAL" exec-out screencap -p > "$1"
  "$_TAPWRIGHT_DIR/shrink-screenshot.sh" "$1"
}

# Cheap assertions on a dumped hierarchy.
has_plus() {
  grep -q '+' "$1"
}

assert_no_plus() {
  ! grep -oE '\+[0-9]' "$1" >/dev/null 2>&1
}
