#!/usr/bin/env bash
# Smoke-test a deployed Flutter web frontend on Vercel.
#
# Usage:
#   bash scripts/smoke-vercel-web.sh https://mkg-tax-mobile.vercel.app
#   bash scripts/smoke-vercel-web.sh   # defaults to production alias

set -euo pipefail

URL="${1:-https://mkg-tax-mobile.vercel.app}"
URL="${URL%/}"

echo "smoke-vercel-web: probing $URL"

fail=0
check() {
  local path="$1"
  local expect_re="$2"
  local code body
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' --max-time 30 -L "$URL$path" || echo "000")"
  if [[ "$code" != "200" ]]; then
    echo "smoke-vercel-web: FAIL $path → HTTP $code"
    fail=1
    rm -f "$body"
    return
  fi
  if ! grep -Eiq "$expect_re" "$body"; then
    echo "smoke-vercel-web: FAIL $path → body missing /$expect_re/"
    fail=1
  else
    echo "smoke-vercel-web: OK   $path → HTTP $code"
  fi
  rm -f "$body"
}

# Flutter web shell + SPA index
check "/" "flutter|main\\.dart\\.js|flutter_bootstrap"
check "/index.html" "flutter|main\\.dart\\.js|flutter_bootstrap"
check "/manifest.json" "name|short_name|MKG|Tax"

# API the browser will call (public health; not hosted on Vercel)
API_BASE="${API_BASE_URL:-https://app.mkgtaxconsultants.com/api/v1}"
api_code="$(curl -sS -o /tmp/mkg-api-health.json -w '%{http_code}' --max-time 30 "$API_BASE/health" || echo "000")"
if [[ "$api_code" != "200" ]]; then
  echo "smoke-vercel-web: FAIL API health $API_BASE/health → HTTP $api_code"
  fail=1
else
  echo "smoke-vercel-web: OK   API health $API_BASE/health → HTTP $api_code"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "smoke-vercel-web: FAILED"
  exit 1
fi

echo "smoke-vercel-web: PASSED ($URL)"
