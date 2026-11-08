#!/usr/bin/env bash
# Runs the duo-adapt templates in a throwaway Flutter project: copies the core layer, its tests and
# the debug probe, turns on strict lints, then runs `flutter analyze` and `flutter test` in normal
# and random order. Run it after every template change.
#
# Usage: scripts/test_templates.sh [work_dir]
#   work_dir defaults to a new temp folder. It is kept, so a failure can be inspected.
set -euo pipefail

skill="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
templates="$skill/templates"
work="${1:-$(mktemp -d "${TMPDIR:-/tmp}/duo-templates.XXXXXX")}"
pkg=duo_templates_check
app="$work/$pkg"

if [[ ! -d "$app" ]]; then
  flutter create --no-pub --project-name "$pkg" --platforms ios,android "$app" >/dev/null
fi
cd "$app"
rm -rf lib test
mkdir -p lib/core/responsive lib/core/debug test/duo
printf "import 'package:flutter/material.dart';\n\nvoid main() => runApp(const MaterialApp(home: SizedBox()));\n" > lib/main.dart

copy() { sed "s/__APP_PACKAGE__/$pkg/g" "$1" > "$2"; }
for f in "$templates"/lib/core/responsive/*.dart; do copy "$f" "lib/core/responsive/$(basename "$f")"; done
for f in "$templates"/test/duo/*.dart; do copy "$f" "test/duo/$(basename "$f")"; done
copy "$templates/debug/duo_probe_page.dart" lib/core/debug/duo_probe_page.dart

# capped_screen_util.dart needs flutter_screenutil, at the version it was verified with.
if ! grep -q flutter_screenutil pubspec.yaml; then
  flutter pub add flutter_screenutil:5.9.3 --offline >/dev/null 2>&1 || flutter pub add flutter_screenutil:5.9.3 >/dev/null
fi
flutter pub get --offline >/dev/null 2>&1 || flutter pub get >/dev/null

# Strict settings like the strictest project so far, so a copy needs no lint fixes.
cat > analysis_options.yaml <<'YAML'
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_redundant_argument_values
    - directives_ordering
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - prefer_single_quotes
    - sort_constructors_first
    - unnecessary_lambdas
    - use_super_parameters
YAML

# The import order depends on the package name, so projects with directives_ordering sort the
# imports after copying (shared plan, P2). Do the same here.
dart fix --apply --code=directives_ordering . >/dev/null

echo "== flutter analyze"
flutter analyze
echo "== flutter test"
flutter test
echo "== flutter test (random order)"
flutter test --test-randomize-ordering-seed random
echo "OK: templates pass in $app"
