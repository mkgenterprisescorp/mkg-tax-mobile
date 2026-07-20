#!/usr/bin/env bash
# Performance Guardian — local / CI checks for MKG Tax Flutter.
#
# Exit 0 when soft checks pass. Exit 1 on hard failures (analyze warnings/errors,
# failed tests, oversized assets above thresholds).
#
# Usage:
#   bash scripts/performance-guardian.sh
#   STRICT_BUNDLE=1 bash scripts/performance-guardian.sh   # fail if build/web missing after build

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="${FLUTTER_BIN:-$HOME/flutter/bin}:$PATH"

MAX_ASSET_BYTES="${MAX_ASSET_BYTES:-2097152}"            # 2 MiB per raster asset
MAX_WEB_BUNDLE_BYTES="${MAX_WEB_BUNDLE_BYTES:-62914560}" # 60 MiB build/web (Flutter + CanvasKit)

fail=0

echo "performance-guardian: flutter analyze"
flutter analyze --no-fatal-infos | tee /tmp/mkg-perf-analyze.log
if grep -E 'warning •|error •' /tmp/mkg-perf-analyze.log >/dev/null 2>&1; then
  echo "performance-guardian: FAIL — analyze warnings/errors present"
  fail=1
else
  echo "performance-guardian: analyze OK (infos allowed)"
fi

echo "performance-guardian: flutter test"
flutter test

echo "performance-guardian: oversized assets (threshold ${MAX_ASSET_BYTES} bytes)"
oversized=0
if [[ -d assets ]]; then
  while IFS= read -r -d '' f; do
    sz=$(wc -c <"$f" | tr -d ' ')
    if [[ "$sz" -gt "$MAX_ASSET_BYTES" ]]; then
      echo "  OVERSIZE $sz  $f"
      oversized=1
    fi
  done < <(find assets -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.gif' \) -print0 2>/dev/null)
fi
if [[ "$oversized" -eq 1 ]]; then
  echo "performance-guardian: FAIL — oversized assets"
  fail=1
else
  echo "performance-guardian: assets OK"
fi

echo "performance-guardian: dependency health (informational)"
flutter pub outdated --no-dev 2>/dev/null | head -40 || true

echo "performance-guardian: potentially unused lib files (heuristic)"
# Files under lib/ never imported by relative path from another lib file (soft).
# This is a hint list — not a hard fail (false positives on entrypoints/generated).
hint=0
while IFS= read -r -d '' f; do
  base=$(basename "$f" .dart)
  # skip main and *.g.dart / *.freezed.dart
  [[ "$base" == "main" ]] && continue
  [[ "$f" == *.g.dart || "$f" == *.freezed.dart ]] && continue
  if ! grep -RIn --include='*.dart' -E "import ['\"].*${base}\\.dart['\"]" lib >/dev/null 2>&1; then
    # also check package imports containing path
    rel=${f#lib/}
    if ! grep -RIn --include='*.dart' -F "$rel" lib >/dev/null 2>&1; then
      echo "  HINT maybe-unused: $f"
      hint=$((hint + 1))
    fi
  fi
done < <(find lib -type f -name '*.dart' -print0)
echo "performance-guardian: unused-file hints=$hint (informational)"

if [[ -d build/web ]]; then
  total=$(du -sb build/web | awk '{print $1}')
  echo "performance-guardian: build/web size=${total} bytes (threshold ${MAX_WEB_BUNDLE_BYTES})"
  if [[ "$total" -gt "$MAX_WEB_BUNDLE_BYTES" ]]; then
    echo "performance-guardian: WARN — web bundle above soft threshold"
    if [[ "${STRICT_BUNDLE:-}" == "1" ]]; then
      fail=1
    fi
  fi
else
  echo "performance-guardian: build/web not present (skip bundle size)"
  if [[ "${STRICT_BUNDLE:-}" == "1" ]]; then
    echo "performance-guardian: FAIL — STRICT_BUNDLE requires build/web"
    fail=1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "performance-guardian: FAILED"
  exit 1
fi
echo "performance-guardian: PASSED"
