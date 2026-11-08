#!/usr/bin/env bash
# Compares a project's copy of the duo-adapt core layer with templates/. Both sides get the package
# name replaced and the same `dart format`; import lines are compared as a sorted set and blank
# lines are ignored, so only real code differences show. Prints one line per file:
#   same | differs | missing | skip (capped_screen_util without flutter_screenutil) | extra (project file)
# Exit code 1 when a template file differs or is missing, 0 otherwise.
#
# Usage: scripts/check_sync.sh <project_root> [core_dir] [test_dir] [--diff]
#   core_dir defaults to lib/core/responsive, test_dir to test/duo. --diff prints the differences.
set -euo pipefail

skill="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
templates="$skill/templates"
show_diff=false
args=()
for a in "$@"; do
  if [[ "$a" == --diff ]]; then show_diff=true; else args+=("$a"); fi
done
project="$(cd "${args[0]:?usage: check_sync.sh <project_root> [core_dir] [test_dir] [--diff]}" && pwd)"
core="${args[1]:-lib/core/responsive}"
tests="${args[2]:-test/duo}"
pkg="$(awk '/^name:/ { print $2; exit }' "$project/pubspec.yaml")"
uses_screenutil=false
grep -q 'flutter_screenutil' "$project/pubspec.yaml" && uses_screenutil=true

tmp="$(mktemp -d "${TMPDIR:-/tmp}/duo-sync.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

pairs=()  # "relative path" of files present on both sides
status=0
collect() { # $1 template folder, $2 project folder
  local t name
  for t in "$1"/*.dart; do
    name="$(basename "$t")"
    if [[ ! -f "$project/$2/$name" ]]; then
      if [[ "$name" == capped_screen_util.dart && "$uses_screenutil" == false ]]; then
        echo "skip     $2/$name (no flutter_screenutil)"
      else
        echo "missing  $2/$name"
        status=1
      fi
      continue
    fi
    mkdir -p "$tmp/t/$2" "$tmp/p/$2"
    sed "s/__APP_PACKAGE__/$pkg/g" "$t" > "$tmp/t/$2/$name"
    cp "$project/$2/$name" "$tmp/p/$2/$name"
    pairs+=("$2/$name")
  done
}
collect "$templates/lib/core/responsive" "$core"
collect "$templates/test/duo" "$tests"

if ((${#pairs[@]})); then
  dart format --line-length 120 "$tmp/t" "$tmp/p" >/dev/null 2>&1 || true
fi

normalize() { # sorted directives first, then the code without blank lines
  { grep -E '^(import|export) ' "$1" | sort || true; grep -vE '^(import|export) |^[[:space:]]*$' "$1" || true; } > "$1.norm"
}

for rel in "${pairs[@]+"${pairs[@]}"}"; do
  normalize "$tmp/t/$rel"
  normalize "$tmp/p/$rel"
  if cmp -s "$tmp/t/$rel.norm" "$tmp/p/$rel.norm"; then
    echo "same     $rel"
  else
    echo "differs  $rel"
    status=1
    if $show_diff; then
      diff -u --label "template/$rel" --label "project/$rel" "$tmp/t/$rel.norm" "$tmp/p/$rel.norm" || true
    fi
  fi
done

if [[ -d "$project/$core" ]]; then
  for f in "$project/$core"/*.dart; do
    [[ -e "$f" ]] || continue
    [[ -f "$templates/lib/core/responsive/$(basename "$f")" ]] || echo "extra    $core/$(basename "$f") (project file)"
  done
fi
exit "$status"
