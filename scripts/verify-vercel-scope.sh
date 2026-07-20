#!/usr/bin/env bash
# Fail the build when the Flutter web frontend contains prohibited secrets,
# direct database connection strings, or unapproved DB client packages.
#
# Usage: bash scripts/verify-vercel-scope.sh [web-root]
# Default web-root is the Flutter project root (.).

set -euo pipefail

WEB_ROOT="${1:-.}"
FAILED=0
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "verify-vercel-scope: scanning ${WEB_ROOT}"

SCAN_DIRS=()
for d in lib web assets test; do
  if [[ -d "${WEB_ROOT}/${d}" ]]; then
    SCAN_DIRS+=("${WEB_ROOT}/${d}")
  fi
done
for f in pubspec.yaml vercel.json; do
  if [[ -f "${WEB_ROOT}/${f}" ]]; then
    SCAN_DIRS+=("${WEB_ROOT}/${f}")
  fi
done

if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
  echo "verify-vercel-scope: ERROR — no lib/web/assets trees found under ${WEB_ROOT}"
  exit 1
fi

# Patterns that must never appear as *values / assignments / connection strings*
# in client source. Documentation that only names the ban (e.g. ".env.example"
# comments, "Prohibited:" lists) is filtered out below.
PROHIBITED_PATTERNS=(
  "DATABASE_URL"
  "NEON_DATABASE_URL"
  "PGHOST"
  "PGUSER"
  "PGPASSWORD"
  "PGDATABASE"
  "IRS_MEF_PRIVATE_KEY"
  "IRS_MEF_CERTIFICATE"
  "IRS_MEF_CERTIFICATE_PASSWORD"
  "SSN_ENCRYPTION_KEY"
  "TAXPAYER_ENCRYPTION_KEY"
  "JWT_PRIVATE_KEY"
  "DIGITALOCEAN_ACCESS_TOKEN"
  "AWS_SECRET_ACCESS_KEY"
  "STRIPE_SECRET_KEY"
  "SENDGRID_API_KEY"
  "postgresql://"
  "postgres://"
)

EXCLUDE_ARGS=(
  --exclude-dir=build
  --exclude-dir=.dart_tool
  --exclude-dir=.vercel
  --exclude-dir=node_modules
  --exclude-dir=dist
  --exclude-dir=docs
  --exclude='*.map'
  --exclude='*.lock'
  --exclude='*.md'
)

# Lines that are clearly documenting the ban, not embedding a secret.
is_doc_only() {
  local line="$1"
  # Strip path:line: prefix from grep -n output for the test.
  local body="${line#*:}"
  body="${body#*:}"
  if [[ "$body" =~ [Pp]rohibit|[Nn]ever\ (set|put|place)|must\ not|do\ not|banned|FORBIDDEN|out\ of\ scope ]]; then
    return 0
  fi
  # Dart/JS comments that only list forbidden names.
  if [[ "$body" =~ ^[[:space:]]*(///|//|#|\*|/\*) ]]; then
    if [[ ! "$body" =~ (fromEnvironment|getenv|process\.env|String\.fromEnvironment|[[:alnum:]_]+=[[:alnum:]]) ]]; then
      return 0
    fi
  fi
  return 1
}

for pattern in "${PROHIBITED_PATTERNS[@]}"; do
  : >"$TMP"
  if grep -RIn "${EXCLUDE_ARGS[@]}" -e "$pattern" "${SCAN_DIRS[@]}" >"$TMP" 2>/dev/null; then
    real=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if is_doc_only "$line"; then
        continue
      fi
      echo "$line"
      real=1
    done <"$TMP"
    if [[ "$real" -eq 1 ]]; then
      echo "verify-vercel-scope: FAIL — prohibited frontend value detected: $pattern"
      FAILED=1
    fi
  fi
done

# Assignment / fromEnvironment usage of secret names (high confidence).
ASSIGN_PATTERNS=(
  "fromEnvironment\(['\"]DATABASE_URL"
  "fromEnvironment\(['\"]NEON_"
  "fromEnvironment\(['\"]PGPASSWORD"
  "fromEnvironment\(['\"]IRS_MEF_"
  "fromEnvironment\(['\"]SSN_ENCRYPTION"
  "fromEnvironment\(['\"]TAXPAYER_ENCRYPTION"
  "DATABASE_URL[[:space:]]*="
  "NEON_DATABASE_URL[[:space:]]*="
  "postgresql://[^[:space:]]+"
  "postgres://[^[:space:]]+"
)

for pattern in "${ASSIGN_PATTERNS[@]}"; do
  if grep -RInE "${EXCLUDE_ARGS[@]}" -e "$pattern" "${SCAN_DIRS[@]}" 2>/dev/null; then
    echo "verify-vercel-scope: FAIL — secret assignment / connection string pattern: $pattern"
    FAILED=1
  fi
done

PROHIBITED_PACKAGES=(postgres postgres_pool drift sqflite prisma)
if [[ -f "${WEB_ROOT}/pubspec.yaml" ]]; then
  for pkg in "${PROHIBITED_PACKAGES[@]}"; do
    if grep -E "^[[:space:]]*${pkg}:" "${WEB_ROOT}/pubspec.yaml" >/dev/null 2>&1; then
      echo "verify-vercel-scope: FAIL — unapproved database-related package in pubspec.yaml: $pkg"
      FAILED=1
    fi
  done
fi

PROHIBITED_NPM=("\"pg\"" "\"postgres\"" "\"@neondatabase/serverless\"" "\"prisma\"" "\"drizzle-orm\"" "\"sequelize\"" "\"typeorm\"")
if [[ -f "${WEB_ROOT}/package.json" ]]; then
  for pkg in "${PROHIBITED_NPM[@]}"; do
    if grep -F "$pkg" "${WEB_ROOT}/package.json" >/dev/null 2>&1; then
      echo "verify-vercel-scope: FAIL — unapproved database package in package.json: $pkg"
      FAILED=1
    fi
  done
fi

if [[ -d "${WEB_ROOT}/lib" ]]; then
  if grep -RIn --include='*.dart' -E 'ep-[a-z0-9-]+\.neon\.tech' "${WEB_ROOT}/lib" 2>/dev/null; then
    echo "verify-vercel-scope: FAIL — Neon host reference found in Dart sources"
    FAILED=1
  fi
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo "verify-vercel-scope: FAILED — frontend is outside approved Vercel scope."
  exit 1
fi

echo "verify-vercel-scope: Vercel frontend scope verification passed."
